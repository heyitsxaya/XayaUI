#!/usr/bin/env python3
"""Offline test (XayaUI_Rules_Options 0.6.82): "Maintain aspect ratio" in a group's "Every display: size" section (Group tab).
Her request (REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s rows 24-25): "add maintain aspect ratio to the every display option"; her
decision: a tick box labelled "Maintain aspect ratio" in "Every display: size", off by default; while it is on, changing Display width
changes Display height in the same proportion, and changing height changes width; the proportion is the one the two had when the box
was ticked. Nothing else (a single rule's own size controls are unchanged).
What is checked (V1: the size every display ends up with, read from each display's own stored width / height, and the sliders as drawn):
  - the box is in the section, labelled exactly, after Display height; its tooltip is one sentence;
  - off by default: a width change leaves every display's height alone (as before);
  - ticked at 64 x 32: width 96 gives height 48 on every display (nested group too), height 24 gives width 48;
  - rounding to whole pixels (width 51 at 2:1 gives height 26, i.e. 25.5 rounded half up);
  - clamping: the other side stays within 8-512 (height 512 at 2:1 gives width 512; width 8 at 2:1 gives height 8); the proportion
    ticked is kept, so a later change inside the range gets it back (height 32 gives width 64 again);
  - unticked: the stored proportion is gone, a width change leaves height alone again;
  - the proportion is stored on the group (f.dispAspect, saved with the group), so it survives a rebuild of the page;
  - an edit-locked rule is still left out;
  - a rule's own Display tab and a cue's own size controls have no such box (nothing else changed).
Run: python3 tests/group_aspect_ratio_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
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
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS")
check("settings window and rule editor loaded", ns and ns.GroupDisplayArgs ~= nil and ns.BuildOptionsTable ~= nil)
if not (ns and ns.GroupDisplayArgs) then return R end
local function rule(name) local r = ns.NewRule(); r.name = name; r.enabled = true; ns.NormalizeRule(r); return r end
ns.folders = { { id = "fG", name = "Group G" }, { id = "fN", name = "Nested", parent = "fG" } }
ns.rules = {}
local P1 = rule("P1"); P1.folder = "fG"; ns.rules[#ns.rules + 1] = P1
local P2 = rule("P2"); P2.folder = "fN"; ns.rules[#ns.rules + 1] = P2
local c1 = ns.NewCueRule(P1, "icon"); local c2 = ns.NewCueRule(P1, "texture"); local c3 = ns.NewCueRule(P2, "icon")
local all = { c1, c2, c3 }
local function setAll(w, h) for _, c in ipairs(all) do c.visual.w, c.visual.h = w, h end end
local function sizes() local t = {}; for _, c in ipairs(all) do t[#t + 1] = tostring(c.visual.w) .. "x" .. tostring(c.visual.h) end; return table.concat(t, " ") end
local function allAre(w, h) for _, c in ipairs(all) do if c.visual.w ~= w or c.visual.h ~= h then return false end end; return true end
local function fr(fid)
  local out = {}
  local function inF(id) while id do if id == fid then return true end; local f; for _, x in ipairs(ns.folders) do if x.id == id then f = x end end; id = f and f.parent end return false end
  for _, r in ipairs(ns.rules) do if r.folder and inF(r.folder) then out[#out + 1] = r end end
  return out
end
local G = ns.folders[1]
local function S() return ns.GroupDisplayArgs(G, fr, function() end).size.args.body.args end
local s = S()
local box = s.aspect
check("the section has a tick box labelled exactly 'Maintain aspect ratio'", box ~= nil and box.type == "toggle" and box.name == "Maintain aspect ratio", box and box.name)
if not box then return R end
check("  ...placed after Display height and before Zoom / crop edges", s.h.order < box.order and box.order < s.zoom.order, tostring(box.order))
local tip = type(box.desc) == "function" and box.desc() or box.desc
local _, dots = tostring(tip):gsub("%.", "")
check("  ...its tooltip is one short sentence", type(tip) == "string" and dots == 1 and #tip <= 120, tip)
check("  ...unticked by default (nothing stored on the group)", box.get() == false and G.dispAspect == nil)
setAll(64, 32)
s.w.set(nil, 96)
check("off: a width change leaves every height alone (as before)", allAre(96, 32), sizes())
setAll(64, 32)
box.set(nil, true)
check("ticking it stores the proportion the sliders show (64 / 32) on the group", G.dispAspect ~= nil and math.abs(G.dispAspect - 2) < 1e-9 and box.get() == true, tostring(G.dispAspect))
check("ticking it changes no display's size", allAre(64, 32), sizes())
s.w.set(nil, 96)
check("on: width 96 gives height 48 on every display (nested group too)", allAre(96, 48), sizes())
check("  ...and the sliders show 96 and 48", s.w.get() == 96 and s.h.get() == 48, tostring(s.w.get()) .. "x" .. tostring(s.h.get()))
s.h.set(nil, 24)
check("on: height 24 gives width 48", allAre(48, 24), sizes())
s.w.set(nil, 51)
check("whole pixels: width 51 at 2:1 gives height 26 (25.5 rounded up)", allAre(51, 26), sizes())
s.h.set(nil, 512)
check("clamped: height 512 at 2:1 gives width 512 (not 1024)", allAre(512, 512), sizes())
check("  ...the proportion ticked is kept on the group", math.abs((G.dispAspect or 0) - 2) < 1e-9, tostring(G.dispAspect))
s.h.set(nil, 32)
check("  ...so height 32 gives width 64 again", allAre(64, 32), sizes())
s.w.set(nil, 8)
check("clamped: width 8 at 2:1 gives height 8 (not 4)", allAre(8, 8), sizes())
-- a rebuilt page (the window redrawn, or a /reload: the group table is what is saved) keeps the box ticked and the proportion
setAll(64, 32)
local s2 = S()
check("a rebuilt page shows the box still ticked", s2.aspect.get() == true)
s2.w.set(nil, 100)
check("  ...and keeps the proportion ticked (width 100 gives height 50)", allAre(100, 50), sizes())
-- a tall proportion (1:2): width changes height the other way round
setAll(64, 32); s2.aspect.set(nil, false); setAll(20, 40); s2.aspect.set(nil, true)
s2.h.set(nil, 100)
check("1:2 ticked at 20 x 40: height 100 gives width 50", allAre(50, 100), sizes())
s2.aspect.set(nil, false)
check("unticked: the stored proportion is gone", G.dispAspect == nil and s2.aspect.get() == false)
s2.w.set(nil, 70)
check("unticked: a width change leaves every height alone again", allAre(70, 100), sizes())
-- an edit-locked rule stays out
setAll(64, 32); s2.aspect.set(nil, true)
P2.editLocked = true
local s3 = S()
s3.w.set(nil, 80)
check("an edit-locked rule's display is left out (the others follow the proportion)", c1.visual.w == 80 and c1.visual.h == 40 and c2.visual.h == 40 and c3.visual.w == 64 and c3.visual.h == 32, sizes())
P2.editLocked = nil
s3.aspect.set(nil, false)
-- nothing else: a rule's own Display tab and its cues' editors have no such box
local found = false
local function scan(t, d)
  if type(t) ~= "table" or d > 30 or found then return end
  if t.name == "Maintain aspect ratio" then found = true; return end
  for _, v in pairs(t.args or {}) do scan(v, d + 1) end
end
scan(ns.BuildDisplayTab(P1, function() end, function() end), 0)
check("a rule's own Display tab has no 'Maintain aspect ratio' box", not found)
local built = ns.BuildOptionsTable()
local GP
local function findG(t, d)
  if type(t) ~= "table" or d > 30 or GP then return end
  if t.type == "group" and t.args and t.args.pageGroup and t.args.pageDisplay then
    local nm = type(t.name) == "function" and t.name() or t.name
    if tostring(nm):find("Group G", 1, true) then GP = t; return end
  end
  for _, v in pairs(t.args or {}) do findG(v, d + 1) end
end
findG(built, 0)
local PG = GP and GP.args.pageGroup.args
check("the real group page: the box is in the size section on the Group tab", PG and PG.size and PG.size.args.body.args.aspect ~= nil and PG.size.args.body.args.aspect.name == "Maintain aspect ratio")
local nBoxes = 0
local function count(t, d)
  if type(t) ~= "table" or d > 40 then return end
  if t.name == "Maintain aspect ratio" then nBoxes = nBoxes + 1 end
  for _, v in pairs(t.args or {}) do count(v, d + 1) end
end
-- this group's own tabs only (its nested groups are tree children of the page and have their own box)
for k, v in pairs(GP and GP.args or {}) do if tostring(k):find("^page") or tostring(k):find("^tab") then count(v, 0) end end
check("  ...and nowhere else on the group page's tabs (one box)", nBoxes == 1, nBoxes)
local RE
local function findR(t, d)
  if type(t) ~= "table" or d > 30 or RE then return end
  if t.type == "group" and t.childGroups == "tab" and t.args and t.args.cues and t.args.trigger then
    local nm = type(t.name) == "function" and t.name() or t.name
    if nm == "P1" then RE = t; return end
  end
  for _, v in pairs(t.args or {}) do findR(v, d + 1) end
end
findR(built, 0)
found = false
if RE then scan(RE, 0) end
check("a rule's editor (Cues tab included) has no such box", RE ~= nil and not found)
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
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + str(name)[:600])
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
