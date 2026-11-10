#!/usr/bin/env python3
"""Opening a rule or a group from the screen lands on its page (review R10, R11; docs/plans/RULES-REVIEW-2026-11-10.md).
R10: clicking a display in the mover view (ns.EditRule) passes the display's own rule, which is mostly a CUE; a cue has no row of its own
(it shows inside its rule), so the window fell back to the Smart Categories front page; a rule with a type also switched the window from
Enabled to Smart Categories. R11: clicking a group's name tag (ns.EditFolder) asked for the group's Smart Categories path, where every
group row is hidden, so the window showed the Smart Categories front page too.
Checked on the real addons in the stand-in game, after the window has redrawn (the tree's own selection: a row that does not exist is
replaced by the tree's first row when it draws):
  A Enabled open, a cue's display clicked: Enabled stays open, its rule's row is selected, on the rule's Cues tab
  B Enabled open, a rule clicked: Enabled stays open on the rule's row
  C Smart Categories open, a cue clicked: Smart Categories stays open on the rule's row under its type (not the front page)
  D a group's tag clicked with Enabled open, and with Smart Categories open: Enabled > Loaded, on the group's row
  E a nested group: its row under its parent group
  F a group holding only a disabled rule: Rules > Disabled, on the group's row
Run: python3 tests/fix_u5rulestree_edit_jump_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
check("the settings window addon is loaded", ns and ns.OptionsApi and ns.OptionsApi.EditRule and ns.OptionsApi.EditFolder and ACD)
if not (ns and ns.OptionsApi and ns.OptionsApi.EditRule and ACD) then return R end
ns.Print = function() end
local APP = "CueRules"
local function mkRule(name, folder)
  local r = ns.NewRule(); r.name = name; r.folder = folder and folder.id or nil; r.enabled = true
  r.useBuff, r.buffID, r.buffState = true, 1001 + #ns.rules, "present"
  r.visual.enabled, r.sound.enabled = false, false
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  return r
end
local function idx(r) for i, x in ipairs(ns.rules) do if x == r then return i end end end
local f = ns.NewFolder("Jump Group")
local r = mkRule("Jump Rule", f)
local cue = ns.NewCueRule(r, "icon")
local fp = ns.NewFolder("Outer Group"); local fc = ns.NewFolder("Inner Group", fp.id)
local rc = mkRule("Inner Rule", fc)
local fd = ns.NewFolder("Off Group")
local rd = mkRule("Off Rule", fd); rd.enabled = false
ns.MarkDirty(); W.tick(0.1, 3)
check("the test's rule has a cue with a display (an icon), of a smart type", cue and cue.isCue and cue.visual.enabled and ns.SmartMatch(r, "smart_icon"))
local function open()
  if not (ACD.OpenFrames and ACD.OpenFrames[APP]) then pcall(ns.ToggleUI) end
  W.tick(0.1, 3)
end
local function goto(...) ACD:SelectGroup(APP, ...); W.tick(0.1, 3) end
-- what the window shows after it has redrawn: the Rules sub-tab and the sidebar row the tree has selected
local function shown()
  W.tick(0.1, 4)
  local S = ns.RulesTreeStatus()
  return ns.CurrentSub(), S and S.selected
end
local function ruleTab(sub, sel)
  local p = { "cooldowns", sub }
  for seg in tostring(sel):gmatch("[^\001]+") do p[#p + 1] = seg end
  local st = ACD:GetStatusTable(APP, p)
  return st and st.groups and st.groups.selected
end
local rk = "rule" .. idx(r)
open()

-- A
goto("cooldowns", "enabledTab", "loaded")
ns.EditRule(cue)
local sub, sel = shown()
check("A Enabled open, the cue's display clicked: Enabled stays open", sub == "enabledTab", sub)
check("A ...the rule's row is selected (Loaded > Jump Group > Jump Rule)", sel == "loaded\001" .. f.id .. "\001" .. rk, sel)
check("A ...on the rule's Cues tab", ruleTab(sub, sel) == "cues", ruleTab(sub, sel))

-- B
goto("cooldowns", "enabledTab", "loaded")
ns.EditRule(r)
sub, sel = shown()
check("B Enabled open, the rule clicked: Enabled stays open, on the rule's row", sub == "enabledTab" and sel == "loaded\001" .. f.id .. "\001" .. rk, tostring(sub) .. " " .. tostring(sel))

-- C
goto("cooldowns", "smartTab", "all")
ns.EditRule(cue)
sub, sel = shown()
check("C Smart Categories open, the cue clicked: Smart Categories stays open", sub == "smartTab", sub)
check("C ...on the rule's row under its type, not the front page", sel == "all\001smart\001smart_icon\001" .. rk, sel)
check("C ...on the rule's Cues tab", ruleTab(sub, sel) == "cues", ruleTab(sub, sel))

-- D
goto("cooldowns", "enabledTab", "loaded")
ns.EditFolder(f)
sub, sel = shown()
check("D Enabled open, the group's tag clicked: Loaded > the group's row", sub == "enabledTab" and sel == "loaded\001" .. f.id, tostring(sub) .. " " .. tostring(sel))
goto("cooldowns", "smartTab", "all")
ns.EditFolder(f)
sub, sel = shown()
check("D Smart Categories open, the group's tag clicked: Enabled > Loaded > the group's row (not the Smart Categories front page)",
  sub == "enabledTab" and sel == "loaded\001" .. f.id, tostring(sub) .. " " .. tostring(sel))

-- E
ns.EditFolder(fc)
sub, sel = shown()
check("E a nested group: its row under its parent group", sub == "enabledTab" and sel == "loaded\001" .. fp.id .. "\001" .. fc.id, tostring(sub) .. " " .. tostring(sel))

-- F
goto("cooldowns", "enabledTab", "loaded")
ns.EditFolder(fd)
sub, sel = shown()
check("F a group holding only a disabled rule: Rules > Disabled, on the group's row", sub == "disabledTab" and sel == "disabled\001" .. fd.id, tostring(sub) .. " " .. tostring(sel))
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
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
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
