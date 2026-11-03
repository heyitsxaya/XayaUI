#!/usr/bin/env python3
"""Offline test (Options 0.6.3): the rule editor's tab order (Display | Trigger | Cues | Conditions | Actions | Load | Info), the Display
tab (the rule as the container of its cues: settings written to every display cue at once), the hover tooltip moved there, and the
open / close button (arg.xuiChevron) on trigger, cue, and condition headers instead of an arrow inside the title text.
Run: python3 tests/display_tab_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok) R[#R + 1] = { name, ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS")
check("settings window addon loaded", ns and ns.BuildOptionsTable ~= nil and ns.BuildDisplayTab ~= nil)
if not (ns and ns.BuildOptionsTable and ns.BuildDisplayTab) then return R end
local function rule(name, enabled) local r = ns.NewRule(); r.name = name; r.enabled = enabled; ns.NormalizeRule(r); return r end
ns.folders = {}
local A = rule("Shell", true); A.useBuff = true; A.buffID = 48707; A.buffState = "present"
ns.rules = { A }
local i1 = ns.NewCueRule(A, "icon"); local t1 = ns.NewCueRule(A, "text"); local s1 = ns.NewCueRule(A, "sound")
i1.visual.x, i1.visual.y = 10, -19
t1.visual.x, t1.visual.y = 30, 5
local OLD = rule("Old style", true); OLD.visual.enabled = true; OLD.visual.x = 7
ns.rules[#ns.rules + 1] = OLD
local built = ns.BuildOptionsTable()
-- find the rule's editor group (it sits in the Smart Categories tree and the Enabled lists; any copy will do)
local function find(t, want, depth)
  if type(t) ~= "table" or depth > 30 then return nil end
  if t.type == "group" and t.childGroups == "tab" and t.args and t.args.trigger and t.args.rule and t.args.load then
    local nm = type(t.name) == "function" and t.name() or t.name
    if nm == want then return t end
  end
  for _, v in pairs(t.args or {}) do local f = find(v, want, depth + 1); if f then return f end end
end
local G = find(built, "Shell", 0)
check("rule editor found", G ~= nil)
if not G then return R end
local a = G.args
local function ord(k) return a[k] and a[k].order end
check("tab order Display | Trigger | Cues | Conditions | Actions | Load | Info",
  ord("display") < ord("trigger") and ord("trigger") < ord("cues") and ord("cues") < ord("conditions") and ord("conditions") < ord("actions")
  and ord("actions") < ord("load") and ord("load") < ord("rule"))
check("Info is the last tab and named Info", a.rule.name == "Info" and a.display.name == "Display")
local D = a.display.args
check("Display lists the rule's two display cues (not the sound cue)", #ns.RuleDisplays(A) == 2 and D.shows.name():find("Icon 1", 1, true) and D.shows.name():find("Text 1", 1, true) and not D.shows.name():find("Sound", 1, true))
-- hover tooltip: one switch for every display cue
check("hover tooltip off at first", D.hoverTip.get() == false)
D.hoverTip.set(nil, true)
check("hover tooltip on writes every display cue", i1.visual.hoverTip == true and t1.visual.hoverTip == true and not s1.visual.hoverTip)
i1.visual.hoverTip = false
check("mixed state: box unticked and the note says 1 of 2", D.hoverTip.get() == false and D.hoverMixed.hidden() == false and D.hoverMixed.name():find("1 of 2", 1, true))
D.hoverTip.set(nil, true)
local n0 = #ns.CuesOf(A)
D.add_texture.func()
local newC = ns.CuesOf(A)[n0 + 1]
check("+ Texture adds a texture cue that takes the hover tooltip", newC and newC.cueKind == "texture" and newC.visual.hoverTip == true)
-- position as a group: the first display is the reference, all move by the same amount
D.posX.set(nil, 25)
check("X moves every display by the same amount (spacing kept)", i1.visual.x == 25 and t1.visual.x == 45)
D.posY.set(nil, -9)
check("Y moves every display by the same amount", i1.visual.y == -9 and t1.visual.y == 15)
check("the sliders show the first display's numbers", D.posX.get() == 25 and D.posY.get() == -9)
-- opacity
D.alpha.set(nil, 0.4)
check("opacity written to every display cue", i1.visual.alpha == 0.4 and t1.visual.alpha == 0.4 and newC.visual.alpha == 0.4)
check("no 'different opacities' note when they agree", D.lookMixed.hidden() == true)
t1.visual.alpha = 0.9
check("note shows when they differ", D.lookMixed.hidden() == false)
-- an older rule (own display, no cues) counts as one display
local GO = find(built, "Old style", 0)
check("older rule: its own display is the one display", GO and #ns.RuleDisplays(OLD) == 1 and ns.RuleDisplays(OLD)[1] == OLD)
-- a rule with no display cue: the tab offers the add buttons only
local E = rule("Empty", true); ns.rules[#ns.rules + 1] = E
local DE = ns.BuildDisplayTab(E, function() end, function() end).args
check("no displays: shared settings hidden, add buttons shown", DE.hoverTip.hidden() == true and DE.posX.hidden() == true and DE.add_icon ~= nil)
-- open / close buttons: trigger pane header and cue header carry arg.xuiChevron and no arrow glyph in the title (skin on)
local trig = a.trigger.args
local foundChev, glyph = false, false
local function scan(t, depth)
  if type(t) ~= "table" or depth > 12 then return end
  if t.type == "execute" and type(t.arg) == "table" and type(t.arg.xuiChevron) == "function" then
    foundChev = true
    local nm = type(t.name) == "function" and t.name() or t.name
    if type(nm) == "string" and nm:find("|T", 1, true) then glyph = true end
  end
  for _, v in pairs(t.args or {}) do scan(v, depth + 1) end
end
scan(a.trigger, 0)
check("trigger headers have an open / close button", foundChev)
check("trigger header titles carry no arrow glyph with the skin on", not glyph)
foundChev, glyph = false, false
scan(a.cues, 0)
check("cue headers have an open / close button", foundChev)
check("cue header titles carry no arrow glyph with the skin on", not glyph)
-- the hover tooltip box is gone from each cue's own options (it lives on the Display tab)
local hidden = nil
local function findHover(t, depth)
  if type(t) ~= "table" or depth > 14 then return end
  if t.type == "toggle" and t.name == "Show tooltip on hover" then hidden = t.hidden end
  for _, v in pairs(t.args or {}) do findHover(v, depth + 1) end
end
findHover(a.cues, 0)
check("per-cue 'Show tooltip on hover' is hidden", hidden == true)
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_GameDump"]
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
        if not ok:
            bad += 1
            print("FAIL:", name)
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
