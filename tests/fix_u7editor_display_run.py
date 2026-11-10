#!/usr/bin/env python3
"""Rule editor fixes of unit U7 (docs/plans/RULES-REVIEW-2026-11-10.md R4, R5, R6, R7). Loads the real addons in the stand-in game
(tests/harness), opens the settings window and checks what the player gets.
- R4 a group's Display tab, Border color: drag in the color picker, the window is rebuilt (as the real window does after a change),
     drag again, Cancel: every display keeps its own color (also with Cancel sent before the picker hides). OK on an unchanged color
     leaves nothing behind: the next Cancel on the same swatch still gives each display its own color. Dragging in the drawn picker
     does not rebuild the window at every step; the window redraws once when the picker closes.
- R5 dragging a Bar cue's Width / Opacity slider or its Bar color: the bar takes each value and the window is not rebuilt at each step.
- R6 a locked rule: every control of its cues (art, size, color, text, sound, bar) in its Cues tab is disabled; unlocked, they work.
- R7 Settings > Rule Creation > Keep up to (drafts): dragging it down to 5 and back to 30 keeps all 30 drafts; a lowered number drops
     the oldest drafts when the window closes, and the Drafts page says how many will go.
Run: python3 tests/fix_u7editor_display_run.py   (Lua 5.1 via lupa; slow: the stand-in builds the whole settings window)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function section(name, fn) local ok, err = pcall(fn); if not ok then check(name .. ": ran to its end (a Lua error stopped it)", false, err) end end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
check("settings window addon loaded", ns and ns.BuildOptionsTable ~= nil and ACD ~= nil)
if not (ns and ns.BuildOptionsTable and ACD) then return R end
ns.Print = function() end
CueRulesDB.ui = CueRulesDB.ui or {}
local APP = "CueRules"

local function NewRule(name, folder)
  local r = ns.NewRule(); r.name = name; r.enabled = true; r.folder = folder; r.uid = ns.NewUID()
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  return r
end
local function idx(r) for i, x in ipairs(ns.rules) do if x == r then return i end end end
local function Tree() return ns.BuildOptionsTable() end
local function find(node, key, depth)
  depth = depth or 0
  if type(node) ~= "table" or depth > 18 then return nil end
  local a = node.args
  if type(a) ~= "table" then return nil end
  if a[key] ~= nil then return a[key] end
  for _, c in pairs(a) do local hit = type(c) == "table" and find(c, key, depth + 1); if hit then return hit end end
end
local function RuleNode(T, r)
  local i = idx(r); local g = i and find(T, "rule" .. i)
  if g and g.xuiStub then ns.OptionsApi.FillRule(g) end
  return g
end
local function FolderNode(T, f) return find(T, f.id) end
local function widget(typ, name)
  local of = ACD.OpenFrames and ACD.OpenFrames[APP]
  local hit
  local function walk(w, d)
    if hit or type(w) ~= "table" or d > 50 then return end
    local o = w.GetUserData and w:GetUserData("option")
    if o and w.type == typ and o.name == name and w.frame and w.frame:IsVisible() then hit = w; return end
    for _, c in ipairs(w.children or {}) do walk(c, d + 1) end
  end
  walk(of, 0)
  return hit
end
local function col3(c) return ("%s,%s,%s"):format(c[1], c[2], c[3]) end
local builds = 0
local B0 = ns.BuildOptionsTable
ns.BuildOptionsTable = function(...) builds = builds + 1; return B0(...) end

-- R4 (option tables, rebuilt between changes as the real window does) ------------------------------------------------------------
local G = ns.NewFolder("U7 colors")
local A = NewRule("Color A", G.id); A.visual.enabled = true; A.visual.border = { enabled = true, size = 1, color = { 1, 0, 0, 1 } }
local Bd = NewRule("Color B", G.id); Bd.visual.enabled = true; Bd.visual.border = { enabled = true, size = 1, color = { 0, 0, 1, 1 } }
section("R4", function()
  local col = find(FolderNode(Tree(), G), "bdColor")
  check("R4 the group's Border color picker is there", col ~= nil)
  local r0, g0, b0, a0 = col.get()
  ColorPickerFrame:Show()
  col.set(nil, 0, 1, 0, 1)                                   -- first drag step
  col = find(FolderNode(Tree(), G), "bdColor")               -- the window is rebuilt
  col.set(nil, 0, 0.8, 0, 1)                                 -- dragging on
  local dragged = A.visual.border.color[2] == 0.8 and Bd.visual.border.color[2] == 0.8
  ColorPickerFrame:Hide()
  col.set(nil, r0, g0, b0, a0)                               -- Cancel: AceGUI sends the swatch's start color after the picker hides
  W.tick(1 / 60, 2)
  check("R4 while dragging every display follows", dragged, col3(A.visual.border.color) .. " / " .. col3(Bd.visual.border.color))
  check("R4 drag, window rebuilt, drag, Cancel: each display keeps its own color",
    col3(A.visual.border.color) == "1,0,0" and col3(Bd.visual.border.color) == "0,0,1",
    "A " .. col3(A.visual.border.color) .. "  B " .. col3(Bd.visual.border.color))
  -- Cancel sent while the picker is still shown, then it hides
  col = find(FolderNode(Tree(), G), "bdColor")
  ColorPickerFrame:Show()
  col.set(nil, 0, 1, 0, 1)
  col = find(FolderNode(Tree(), G), "bdColor")
  col.set(nil, r0, g0, b0, a0)
  ColorPickerFrame:Hide(); W.tick(1 / 60, 2)
  check("R4 Cancel before the picker hides: each display keeps its own color",
    col3(A.visual.border.color) == "1,0,0" and col3(Bd.visual.border.color) == "0,0,1",
    "A " .. col3(A.visual.border.color) .. "  B " .. col3(Bd.visual.border.color))
  -- OK: every display takes the new color; AceGUI sends nothing more when it is unchanged
  col = find(FolderNode(Tree(), G), "bdColor")
  ColorPickerFrame:Show(); col.set(nil, 0.5, 0.5, 0.5, 1); ColorPickerFrame:Hide(); W.tick(1 / 60, 2)
  check("R4 OK on a new color: every display gets it", A.visual.border.color[1] == 0.5 and Bd.visual.border.color[1] == 0.5)
  -- then B gets its own color back, and the picker is used again on the same swatch: Cancel keeps each display's own
  Bd.visual.border.color = { 0, 0, 1, 1 }
  col = find(FolderNode(Tree(), G), "bdColor")
  local s1, s2, s3, s4 = col.get()
  ColorPickerFrame:Show(); col.set(nil, 0, 1, 0, 1); ColorPickerFrame:Hide(); col.set(nil, s1, s2, s3, s4); W.tick(1 / 60, 2)
  check("R4 after an OK with nothing more sent, the next Cancel still keeps each display's own color",
    col3(A.visual.border.color) == "0.5,0.5,0.5" and col3(Bd.visual.border.color) == "0,0,1",
    "A " .. col3(A.visual.border.color) .. "  B " .. col3(Bd.visual.border.color))
  A.visual.border.color = { 1, 0, 0, 1 }
end)

-- open the window (R4 drawn, R5) -------------------------------------------------------------------------------------------------
pcall(ns.ToggleUI); W.tick(0.1, 3)
check("the settings window is open", ACD.OpenFrames and ACD.OpenFrames[APP] ~= nil)

section("R4 drawn", function()
  ACD:SelectGroup(APP, "cooldowns", "enabledTab", "loaded", G.id); W.tick(0.1, 3)
  ns.folderTab[G] = "display"; ns.UI.Notify(); W.tick(1 / 60, 3)
  local cp = widget("ColorPicker", "Border color")
  check("R4 the group's Display tab shows its Border color swatch", cp ~= nil)
  if not cp then return end
  builds = 0
  ColorPickerFrame:Show()
  local took = 0
  for step = 1, 5 do
    local g = step * 0.2
    cp:Fire("OnValueChanged", 0, g, 0, 1)   -- (AceGUI's colour picker fires this while the colour wheel is dragged)
    if A.visual.border.color[2] == g and Bd.visual.border.color[2] == g then took = took + 1 end
    W.tick(1 / 60, 1)
  end
  check("R4 dragging in the picker: every display takes each color", took == 5, took)
  check("R4 ...and the window is not rebuilt during the drag", builds == 0, builds .. " builds")
  ColorPickerFrame:Hide(); W.tick(1 / 60, 3)
  check("R4 the window redraws once when the picker closes", builds == 1, builds .. " builds")
end)

-- R5 -----------------------------------------------------------------------------------------------------------------------------
section("R5", function()
  local F = ns.NewFolder("U7 bars")
  local P = NewRule("Bar parent", F.id); P.useCooldown, P.spellID, P.cdState = true, 1001, "ready"
  local cue = ns.NewCueRule(P, "bar")
  local bar = find(find(RuleNode(Tree(), P), "cues"), "bar")
  local w, al, bc = bar and bar.args.w, bar and bar.args.alpha, bar and bar.args.color
  check("R5 the Bar cue's Width / Opacity / Bar color controls are there", w and al and bc and w.type == "range" and bc.type == "color")
  if not (w and al and bc) then return end
  builds = 0
  local followed = 0
  for step = 1, 10 do
    local v = 100 + step * 10
    w.set(nil, v)
    if cue.visual.w == v then followed = followed + 1 end
    W.tick(1 / 60, 1)
  end
  check("R5 dragging Width: the bar takes each value", followed == 10, followed)
  check("R5 ...and the window is not rebuilt at each step", builds == 0, builds .. " builds")
  builds = 0
  for step = 1, 5 do al.set(nil, 1 - step * 0.1); W.tick(1 / 60, 1) end
  check("R5 dragging Opacity: no rebuild at each step", builds == 0 and math.abs((cue.visual.alpha or 0) - 0.5) < 0.001, builds .. " builds, alpha " .. tostring(cue.visual.alpha))
  local B = ns.BarCueSettings(cue.visual)
  B.colorMode = "fixed"
  builds = 0
  for step = 1, 5 do bc.set(nil, step * 0.2, 0, 0, 1); W.tick(1 / 60, 1) end
  check("R5 dragging Bar color: the bar takes it, no rebuild at each step", builds == 0 and B.color and B.color[1] == 1, builds .. " builds")
end)

-- R6 -----------------------------------------------------------------------------------------------------------------------------
section("R6", function()
  local F = ns.NewFolder("U7 lock")
  local P = NewRule("Locked parent", F.id); P.useCooldown, P.spellID, P.cdState = true, 1002, "ready"
  ns.NewCueRule(P, "icon"); ns.NewCueRule(P, "sound"); ns.NewCueRule(P, "bar"); ns.NewCueRule(P, "text")
  local function count(locked)
    P.editLocked = locked or nil
    local cues = find(RuleNode(Tree(), P), "cues")
    local live, total, names = 0, 0, {}
    local function scan(n, d, path)
      if type(n) ~= "table" or d > 20 then return end
      for k, c in pairs(n.args or {}) do
        if type(c) == "table" then
          if c.type == "group" then scan(c, d + 1, path .. "/" .. tostring(k))
          elseif c.set and c.type ~= "description" and c.type ~= "header" then
            total = total + 1
            local dis = c.disabled; if type(dis) == "function" then local ok, v = pcall(dis, {}); dis = ok and v end
            if not dis then live = live + 1; if #names < 12 then names[#names + 1] = path .. "/" .. tostring(k) end end
          end
        end
      end
    end
    scan(cues, 0, "cues")
    return live, total, names
  end
  local live, total, names = count(true)
  check("R6 locked rule: every control of its cues is disabled", total > 20 and live == 0, live .. " of " .. total .. " live: " .. table.concat(names, ", "))
  local live2, total2 = count(false)
  check("R6 unlocked again: the cue controls work", total2 > 20 and live2 > total2 / 2, live2 .. " of " .. total2)
end)

-- R7 -----------------------------------------------------------------------------------------------------------------------------
section("R7", function()
  local CoreS = ns.Settings("core")
  CoreS.promptSave = true
  CoreS.drafts = {}
  for i = 1, 30 do CoreS.drafts[i] = { id = "d" .. i, uid = "d" .. i, name = "Draft " .. i, ts = 1000 - i, rules = {} } end
  local _, rules = ns.OptionsApi.RuleEditor.SettingsRows(function() return CoreS end, function() end)
  local dm = rules.args.draftsMax
  check("R7 Keep up to is there and usable with drafts on", dm and not dm.disabled())
  for v = 29, 5, -1 do dm.set(nil, v) end      -- dragged down to 5 ...
  for v = 6, 30 do dm.set(nil, v) end          -- ... and back to 30
  check("R7 dragging Keep up to down to 5 and back to 30 keeps all 30 drafts", #CoreS.drafts == 30, #CoreS.drafts)
  dm.set(nil, 10)
  check("R7 lowered to 10: the drafts stay while the window is open", #CoreS.drafts == 30, #CoreS.drafts)
  local intro = find(Tree(), "draftsTab"); intro = intro and intro.args and intro.args.intro
  check("R7 the Drafts page says the oldest 20 go when the window closes", intro and intro.name():find("oldest 20 will be dropped", 1, true) ~= nil,
    intro and intro.name())
  ns.DraftsOnOpen(); ns.DraftsOnClose()
  check("R7 the window closes: the 10 newest drafts are kept", #CoreS.drafts == 10 and CoreS.drafts[1].id == "d1" and CoreS.drafts[10].id == "d10",
    #CoreS.drafts .. " first " .. tostring(CoreS.drafts[1] and CoreS.drafts[1].id))
  CoreS.drafts = {}; CoreS.draftsMax = nil; CoreS.promptSave = nil
end)
ns.BuildOptionsTable = B0
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
