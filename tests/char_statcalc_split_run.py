#!/usr/bin/env python3
"""Character pane split, stages 2 and 3 (Bonus 0.6.37, QoL 0.7.53, XayaUI 0.6.83; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 4.2).
Xaya's Q5 answer: "The Advanced Character Stats pane window is a Bonus feature"; PS-54: "the character pane improvements (stat
organization and configuration) is a separate module from the Stat Calculator which is a bonus feature as already established".
The Stat Calculator panel (XayaUI_Bonus/StatCalculator.lua) is XayaUI Bonus Features' now; its settings were copied, never moved, from
XayaUIQoLDB.characterToolkit into XayaUIBonusDB.characterToolkit (core Modules.lua, the key move). On the real addons in the stand-in
game (tests/harness), with the saved variables carried over a /reload:
  M1  a P5 install (QoL's store holds the whole characterToolkit, Bonus's store none): at the first login every panel key and the switch
      are in Bonus's store with the same values (side "left", text size 13, a spell added by hand, the panel's height); the record says
      migratedFrom "XayaUIQoLDB.characterToolkit", by "XayaUI_Bonus <version>", how many keys; QoL's characterToolkit and CueRulesDB are
      byte-for-byte what they were (copy, never move; QoL may add its own defaults, never change or remove a key); the overlay and tooltip
      keys are not copied; the panel reads Bonus's copy.
  M2  the next load copies nothing again: a panel key changed in QoL's old copy between the loads does not reach Bonus's store; a change
      made in Bonus's settings is kept over the /reload.
  M3  a pre-P5 install (CueRulesDB only): Bonus's store gets the panel keys and the switch from CueRulesDB at its first copy, QoL's the
      rest; the record says migratedFrom "CueRulesDB.characterToolkit"; CueRulesDB unchanged.
  P   profiles: the "QoL" part's characterToolkit is joined from both halves as before the split (the panel's keys from Bonus, the rest
      from QoL); an import writes each key to its half and the switch to both.
  S3  XayaUI QoL off: XayaUI Bonus Features shows nothing extra (no Stat Calculator page, no /xui stats, no Stat Calculator row in the
      minimap list), saves nothing for it, no Lua error; the "statModel" service is XayaUI QoL's and absent. XayaUI Bonus Features
      off: QoL > Improved Character Display (with its Slot Overlays part; V25 R2; Tooltip lines moved to Enhanced Tooltips in V25 R4) is there, no Stat Calculator page or command, QoL's settings untouched.
      Both on: Bonus reads the model only through the service (its file never names ns.StatModel).
Negative control: on f870d78 M1, M3, P (the panel's keys in Bonus's store), S3 (Bonus page) fail: the panel is QoL's there.
Run: python3 tests/char_statcalc_split_run.py   (Lua 5.1 via lupa)."""
import copy, json, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

ROOT = os.path.join(HERE, "..")
results = []


def check(name, ok, extra=None):
    results.append((name, bool(ok)))
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [%s]" % (extra,)))


# her panel set up in QoL 0.7.52 (stand-in values), and her overlay / tooltip choices
OLD_SAVED = {"enabled": True, "panel": True, "side": "left", "detail": "all", "tooltips": False, "fontSize": 13, "opacity": 0.8,
          "advanced": True, "spells": [{"id": 263642, "base": "ap", "kind": "offense"}], "spellFilter": "all", "spellsAll": False,
          "free": {"x": 12, "y": -40}, "panelOpen": False, "sizeMode": "large", "heightSmall": 500, "heightLarge": 900, "tab": "gear",
          "gearSumStyle": "tiles", "whatIf": 0, "whatIfStats": {"crit": 200}, "collapsed": {"map_gear": True}, "statOpen": {"map_ap": True},
          "overlays": True, "ovIlvl": True, "ovSockets": False, "ovEnchants": True, "ovSize": 12, "enchantSlots": {"1": True}, "enchantSlotsSet": True}
PANEL_KEYS = {"panel", "side", "detail", "fontSize", "opacity", "advanced", "spells", "spellFilter", "spellsAll", "free", "panelOpen",
              "sizeMode", "heightSmall", "heightLarge", "tab", "gearSumStyle", "whatIf", "whatIfStats", "collapsed", "statOpen"}
QOL_KEYS = {"tooltips", "overlays", "ovIlvl", "ovSockets", "ovEnchants", "ovSize", "enchantSlots", "enchantSlotsSet"}

LUA = r'''
return function(W, L, MODE)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.5, 10)
local ns = rawget(_G, "XayaUI_NS")
if ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS")
local out = { }
local sc = ns.StatCalc_Cfg and ns.StatCalc_Cfg()
out.panelSide = sc and sc.side
out.panelFont = sc and sc.fontSize
out.statModel = ns.Service("statModel") ~= nil
out.statCalc = ns.Service("statCalc") ~= nil
local pages = ns.BuildSettingsPages and ns.BuildSettingsPages("bonus") or {}
out.bonusPage = pages.statcalc ~= nil and pages.statcalc.name or false
local qp = ns.BuildSettingsPages and ns.BuildSettingsPages("qol") or {}
-- (V25 R2) the slot overlays are a part of QoL > Improved Character Display, which has no panel part; (V25 R4) the tooltip lines are
-- Bonus Features > Enhanced Tooltips' option, not a part of this page
out.qolPage = qp.chardisplay ~= nil and (qp.chardisplay.args.overlayPart ~= nil and qp.chardisplay.args.tipsPart == nil and qp.chardisplay.args.panelPart == nil) or false
out.statsCmd = false
local said = {}
local rawPrint = ns.Print
ns.Print = function(m) said[#said + 1] = tostring(m) end
pcall(ns.RunCommand, "stats", "status")
ns.Print = rawPrint
for _, l in ipairs(said) do if l:find("Stat Calculator:", 1, true) then out.statsCmd = l end end
out.launcher = false
for _, e in ipairs(ns.Launchers and ns.Launchers() or {}) do if e[1] == "stats" then out.launcher = true end end
if MODE == "change-bonus" and sc then sc.side = "right" end
if MODE == "profile" and ns.SettingsLegacyGet then
  out.legacy = ns.SettingsLegacyGet("characterToolkit")
  ns.SettingsLegacyMerge("characterToolkit", { side = "right", overlays = false, enabled = false, marker = 7 })
  local b, q = ns.Settings("bonus").characterToolkit, ns.Settings("qol").characterToolkit
  out.afterImport = { bSide = b and b.side, bOverlays = b and b.overlays, bEnabled = b and b.enabled, bMarker = b and b.marker,
    qSide = q and q.side, qOverlays = q and q.overlays, qEnabled = q and q.enabled, qMarker = q and q.marker }
end
if ns.SettingsKeyMove then local r, now = ns.SettingsKeyMove("characterToolkit"); out.keyMove = r or false; out.keyMovedNow = now and true or false end
return out
end
'''


def session(enabled_filter, saved, mode=""):
    folders = H.find_addons()
    enabled = [n for n in folders if enabled_filter(n)]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": saved}))
    res = L.eval("function(src, W, Ld, m) return loadstring(src)()(W, Ld, m) end")(LUA, world, loader, mode)
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


ALL = lambda n: n != "XayaUI_DevAssist"  # noqa: E731


def main():
    # M1: a P5 install
    cue = {"characterToolkit": copy.deepcopy(OLD_SAVED)}
    p5 = {"XayaUI": {"CueRulesDB": copy.deepcopy(cue)},
          "XayaUI_QoL": {"XayaUIQoLDB": {"storeVersion": 1, "migratedFrom": "CueRulesDB", "characterToolkit": copy.deepcopy(OLD_SAVED)}},
          "XayaUI_Bonus": {"XayaUIBonusDB": {"storeVersion": 1, "migratedFrom": "CueRulesDB", "calculator": {"enabled": True}}}}
    out, s1, errs = session(ALL, copy.deepcopy(p5))
    b = store(s1, "XayaUI_Bonus", "XayaUIBonusDB")
    q = store(s1, "XayaUI_QoL", "XayaUIQoLDB")
    bt = b.get("characterToolkit") or {}
    check("M1 first login of a P5 install: every panel key and the switch are in XayaUIBonusDB.characterToolkit with the same values",
          all(norm(bt.get(k)) == norm(OLD_SAVED[k]) for k in PANEL_KEYS | {"enabled"}),
          {k: (bt.get(k), OLD_SAVED[k]) for k in PANEL_KEYS | {"enabled"} if norm(bt.get(k)) != norm(OLD_SAVED[k])})
    check("  ...the slot overlay and tooltip line keys are not copied (they stay QoL's)", not (set(bt) & QOL_KEYS), sorted(set(bt) & QOL_KEYS))
    rec = (b.get("keyMoves") or {}).get("characterToolkit") or {}
    check("  ...recorded: migratedFrom XayaUIQoLDB.characterToolkit, by XayaUI_Bonus <version>, the day, %d keys" % (len(PANEL_KEYS) + 1),
          rec.get("migratedFrom") == "XayaUIQoLDB.characterToolkit" and str(rec.get("migratedBy", "")).startswith("XayaUI_Bonus ")
          and rec.get("migratedAt") and rec.get("migratedKeys") == len(PANEL_KEYS) + 1, rec)
    check("  ...ns.SettingsKeyMove says the copy was made in this session", out.get("keyMovedNow") is True, out.get("keyMovedNow"))
    check("  ...QoL's characterToolkit keeps every old key with its old value (copy, never move)", kept(OLD_SAVED, q.get("characterToolkit")),
          q.get("characterToolkit"))
    check("  ...CueRulesDB is unchanged", norm(store(s1, "XayaUI", "CueRulesDB").get("characterToolkit")) == norm(OLD_SAVED))
    check("  ...the Stat Calculator reads Bonus's copy (side left, text size 13)", out.get("panelSide") == "left" and out.get("panelFont") == 13,
          (out.get("panelSide"), out.get("panelFont")))
    check("  ...its page is Bonus Features > Stat Calculator; QoL > Improved Character Display has Slot Overlays and no panel part (nor Tooltip lines: V25 R4)",
          out.get("bonusPage") == "Stat Calculator" and out.get("qolPage") is True, (out.get("bonusPage"), out.get("qolPage")))
    check("  ...no Lua error", not errs, errs[:2])
    # M2: the next load
    s1b = copy.deepcopy(s1)
    s1b["XayaUI_QoL"]["XayaUIQoLDB"]["characterToolkit"]["side"] = "right"   # QoL's old copy changed between the loads
    out2, s2, errs2 = session(ALL, s1b, "change-bonus")
    b2 = store(s2, "XayaUI_Bonus", "XayaUIBonusDB")
    check("M2 the next load copies nothing again: a change in QoL's old copy does not reach Bonus's (side still left at login)",
          out2.get("panelSide") == "left" and out2.get("keyMovedNow") is False, (out2.get("panelSide"), out2.get("keyMovedNow")))
    out3, s3, errs3 = session(ALL, s2)
    check("  ...a change made in Bonus's settings is kept over the /reload (side right)", out3.get("panelSide") == "right", out3.get("panelSide"))
    check("  ...the record is kept as it was", norm((b2.get("keyMoves") or {}).get("characterToolkit")) == norm(rec))
    check("  ...no Lua error", not errs2 and not errs3, (errs2 + errs3)[:2])
    # M3: a pre-P5 install
    pre = {"XayaUI": {"CueRulesDB": copy.deepcopy(cue)}}
    out4, s4, errs4 = session(ALL, copy.deepcopy(pre))
    b4, q4 = store(s4, "XayaUI_Bonus", "XayaUIBonusDB"), store(s4, "XayaUI_QoL", "XayaUIQoLDB")
    bt4, qt4 = b4.get("characterToolkit") or {}, q4.get("characterToolkit") or {}
    rec4 = (b4.get("keyMoves") or {}).get("characterToolkit") or {}
    check("M3 a pre-P5 install: Bonus's store gets the panel keys and the switch from CueRulesDB, QoL's the overlay and tooltip keys and the switch",
          all(norm(bt4.get(k)) == norm(OLD_SAVED[k]) for k in PANEL_KEYS | {"enabled"}) and all(norm(qt4.get(k)) == norm(OLD_SAVED[k]) for k in QOL_KEYS | {"enabled"})
          and not (set(bt4) & QOL_KEYS), (sorted(bt4), sorted(qt4)))
    check("  ...recorded: migratedFrom CueRulesDB.characterToolkit", rec4.get("migratedFrom") == "CueRulesDB.characterToolkit", rec4)
    check("  ...CueRulesDB is unchanged; no Lua error", norm(store(s4, "XayaUI", "CueRulesDB").get("characterToolkit")) == norm(OLD_SAVED) and not errs4, errs4[:2])
    # P: profiles
    out5, s5, errs5 = session(ALL, copy.deepcopy(s1), "profile")
    lg = out5.get("legacy") or {}
    check("P the QoL profile part's characterToolkit is joined as before the split (every old key, its old value)", kept(OLD_SAVED, lg), lg)
    ai = out5.get("afterImport") or {}
    check("  ...an import writes the panel's key to Bonus, the overlay key to QoL, the switch to both, any other key to QoL",
          ai.get("bSide") == "right" and ai.get("bOverlays") is None and ai.get("qOverlays") is False and ai.get("bEnabled") is False
          and ai.get("qEnabled") is False and ai.get("qMarker") == 7 and ai.get("bMarker") is None, ai)
    check("  ...no Lua error", not errs5, errs5[:2])
    # S3: XayaUI QoL off
    out6, s6, errs6 = session(lambda n: ALL(n) and n != "XayaUI_QoL", copy.deepcopy(p5))
    b6 = store(s6, "XayaUI_Bonus", "XayaUIBonusDB")
    check("S3 XayaUI QoL off: Bonus Features shows nothing extra: no Stat Calculator page, no /xui stats, no Stat Calculator row",
          out6.get("bonusPage") is False and out6.get("statsCmd") is False and out6.get("launcher") is False, (out6.get("bonusPage"), out6.get("statsCmd"), out6.get("launcher")))
    check("  ...no statModel service (it is XayaUI QoL's); nothing is saved for the panel in Bonus's store", out6.get("statModel") is False
          and "characterToolkit" not in b6 and "keyMoves" not in b6, sorted(b6))
    check("  ...no Lua error", not errs6, errs6[:2])
    out7, s7, errs7 = session(lambda n: ALL(n) and n != "XayaUI_Bonus", copy.deepcopy(p5))
    check("S3 XayaUI Bonus Features off: QoL > Improved Character Display (Slot Overlays) is there; no Stat Calculator page or command",
          out7.get("qolPage") is True and out7.get("bonusPage") is False and out7.get("statsCmd") is False, (out7.get("qolPage"), out7.get("bonusPage"), out7.get("statsCmd")))
    check("  ...QoL's characterToolkit keeps every old key; no Lua error", kept(OLD_SAVED, store(s7, "XayaUI_QoL", "XayaUIQoLDB").get("characterToolkit")) and not errs7, errs7[:2])
    check("S3 both on: the statModel service is there and Bonus Features' Stat Calculator answers (/xui stats status)",
          out.get("statModel") is True and str(out.get("statsCmd") or "").startswith("Stat Calculator: on, panel on"), out.get("statsCmd"))
    src = open(os.path.join(ROOT, "XayaUI_Bonus", "StatCalculator.lua"), encoding="utf-8").read() if os.path.isfile(os.path.join(ROOT, "XayaUI_Bonus", "StatCalculator.lua")) else ""
    code = "\n".join(l.split("--", 1)[0] for l in src.splitlines())
    check("S3 XayaUI_Bonus/StatCalculator.lua reads the model only through the statModel service (never ns.StatModel)",
          src != "" and "ns.StatModel" not in code and 'ns.Service("statModel")' in code)
    bad = sum(1 for _, ok in results if not ok)
    print("%d checks, %d failed" % (len(results), bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
