#!/usr/bin/env python3
"""The rule type picker ("Choose what this rule shows", + New Rule) in the settings window (debug W1; Rules_Options 0.6.79, Options 0.6.94).
#484 (Xaya, 2026-11-07, H6-H9 step 4, her words): "import button has wrong alignment, otherwise good".
#487 (Xaya, 2026-11-07, Rules > Drafts after the audit-opt-bin walkthrough): "????????????????????????" - the picker was drawn at the
top of the Drafts list, its rows overlapping each other.
Loads the real addons in the stand-in game (real AceGUI / AceConfigDialog, real frame positions), opens the window and checks what the
player sees (V1, V11):
  A Smart Categories, + New Rule: the Import row lines up with the rows above it: the same row left edge and width, the icon at the
    same x inside the row and the text at the same x (measured against Dynamic Group, its neighbour, and every other row).
  B no two picker rows overlap (each row starts at or below the bottom of the one above), each row's icon and text sit inside the
    row (both axes), and the text fits the row's height; again at a narrow window (700 px).
  C the picker stays with the sub-tab it was opened in: switch to Drafts and it is not drawn there (the Drafts boxes show, the first
    one right under the Drafts page's own entries); it is forgotten (back on Smart Categories, no picker).
  D + New Rule pressed on Drafts: the picker shows there and the Drafts boxes hide while it is open (never drawn over each other).
  E the picker is forgotten when the window closes: reopened, no picker.
  F the walkthrough "debug-w1" (Dev Assist 0.7.62, V22): registered with pre-fill; its checks run here and judge steps 3 and 4 Pass.
Negative control: on main b0723dd (Rules_Options 0.6.78, Options 0.6.93; the same files as e0d6d16) A to F fail: Import's icon 8 px and
its text 22 px further right and 20 px lower than every other row; 76 px rows stacked 39 px apart; the picker still drawn on Drafts
with the Drafts boxes, and still open after another sub-tab or a closed window; no walkthrough.
Run: python3 tests/picker_rows_layout_run.py   (Lua 5.1 via lupa)"""
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
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
check("settings window addon loaded", ns and ns.BuildOptionsTable ~= nil and ns.UI and ns.UI.NewRule ~= nil)
if not (ns and ns.BuildOptionsTable and ns.UI and ns.UI.NewRule) then return R end
-- two drafts, so the Drafts page has its list (her screenshot: Unnamed rule, Augment Rune, Food Buff)
local core = ns.Settings("core")
core.promptSave = true
core.drafts = { { id = "dA", name = "Augment Rune", ts = 0, rules = {} }, { id = "dB", name = "Food Buff", ts = 0, rules = {} } }
local ACD = LibStub("AceConfigDialog-3.0")
local function root() return ACD.OpenFrames and ACD.OpenFrames["CueRules"] end
local function shownChain(w) local f = w.frame; return f and f:IsShown() and f:IsVisible() end
local function each(fn)
  local function walk(w, d) if not w or d > 40 then return end; fn(w); for _, c in ipairs(w.children or {}) do walk(c, d + 1) end end
  walk(root(), 0)
end
local TITLES = { "Icon", "Texture", "Progress Bar", "Progress Texture", "Text", "Sound Cue", "Static Group", "Custom", "Dynamic Group", "Import" }
local function rows()
  local out = {}
  each(function(w)
    local o = w.GetUserData and w:GetUserData("option")
    local nm = o and type(o.name) == "string" and o.name or ""
    for _, t in ipairs(TITLES) do
      if nm:find("|cffffd100" .. t .. "|r", 1, true) == 1 and shownChain(w) then out[t] = w end
    end
  end)
  return out
end
local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
local function header()
  local hit
  each(function(w) if w.type == "Heading" and w.label and w.label:GetText() == "Choose what this rule shows" and shownChain(w) then hit = w end end)
  return hit
end
local function boxes()
  local out = {}
  each(function(w) if w.type == "InlineGroup" and w.titletext and shownChain(w) then
    local t = w.titletext:GetText(); if t == "Augment Rune" or t == "Food Buff" then out[#out + 1] = w end end end)
  return out
end
local function near(a, b) return a and b and math.abs(a - b) < 0.6 end

pcall(ns.ToggleUI); W.tick(0.05, 6)
check("the window opened", root() ~= nil)
ACD:SelectGroup("CueRules", "cooldowns", "smartTab"); W.tick(0.05, 6)
ns.UI.NewRule(); W.tick(0.05, 10)

local function layout(tag)
  local r = rows()
  check(tag .. ": the picker shows all ten rows", count(r) == 10, count(r))
  if count(r) < 10 then return end
  local ref = r["Dynamic Group"]
  local function geo(w)
    local f = w.frame
    return { l = f:GetLeft(), w = f:GetWidth(), t = f:GetTop(), b = f:GetBottom(), h = f:GetHeight(),
      il = w.image:GetLeft() - f:GetLeft(), tl = w.label:GetLeft() - f:GetLeft(),
      it = w.image:GetTop(), ib = w.image:GetBottom(), lt = w.label:GetTop(), lb = w.label:GetBottom(), lr = w.label:GetRight(), r = f:GetRight(),
      sh = w.label:GetStringHeight() }
  end
  local g, gi = geo(ref), geo(r["Import"])
  if WIDE_W then check(tag .. ": the rows really are narrower here", g.w < WIDE_W - 50, ("%s / %s"):format(g.w, WIDE_W)) else WIDE_W = g.w end
  check(tag .. ": #484 Import row starts at the same x and is as wide as Dynamic Group", near(gi.l, g.l) and near(gi.w, g.w),
    ("Import x %s w %s / Dynamic Group x %s w %s"):format(gi.l, gi.w, g.l, g.w))
  check(tag .. ": #484 Import's icon sits at the same x in its row as Dynamic Group's", near(gi.il, g.il), ("Import +%s / Dynamic Group +%s"):format(gi.il, g.il))
  check(tag .. ": #484 Import's text starts at the same x in its row as Dynamic Group's", near(gi.tl, g.tl), ("Import +%s / Dynamic Group +%s"):format(gi.tl, g.tl))
  check(tag .. ": #484 Import's icon sits at the same height in its row as Dynamic Group's", near(gi.t - gi.it, g.t - g.it), ("Import %s / Dynamic Group %s"):format(gi.t - gi.it, g.t - g.it))
  local same = true
  for _, t in ipairs(TITLES) do local x = geo(r[t]); if not (near(x.il, g.il) and near(x.tl, g.tl) and near(x.l, g.l)) then same = t end end
  check(tag .. ": every row has the same icon column and text indent", same == true, same)
  -- B: no overlap, inside, fits
  local list = {}
  for _, t in ipairs(TITLES) do local x = geo(r[t]); x.name = t; list[#list + 1] = x end
  table.sort(list, function(a, b) return a.t > b.t end)
  local bad
  for i = 2, #list do if list[i].t > list[i - 1].b + 0.5 then bad = ("%s (top %s) overlaps %s (bottom %s)"):format(list[i].name, list[i].t, list[i - 1].name, list[i - 1].b) end end
  check(tag .. ": #487 no two picker rows overlap", bad == nil, bad)
  local out
  for _, x in ipairs(list) do   -- the first row found outside its box
    if out == nil and (x.it > x.t + 0.5 or x.ib < x.b - 0.5 or x.lt > x.t + 0.5 or x.lb < x.b - 0.5 or x.lr > x.r + 0.5 or x.il < -0.5) then out = ("%s: icon %s..%s, text %s..%s (right %s), row %s..%s (right %s)"):format(x.name, x.it, x.ib, x.lt, x.lb, x.lr, x.t, x.b, x.r) end
  end
  check(tag .. ": each row's icon and text sit inside the row (both axes)", out == nil, out)
  local tall
  for _, x in ipairs(list) do if x.sh > x.h + 0.5 then tall = ("%s: text %s px, row %s px"):format(x.name, x.sh, x.h) end end
  check(tag .. ": each row's text fits its height", tall == nil, tall)
end
section("A/B Smart Categories", function() layout("A/B") end)
section("B narrow window", function()
  -- the stand-in does not pass a live window resize down to the page's rows (no OnSizeChanged chain), so the window is closed and
  -- opened again at 700 px wide (AceConfigDialog's saved size), and the picker opened again
  local st = ACD:GetStatusTable("CueRules")
  local w0 = st.width
  pcall(ns.ToggleUI); W.tick(0.1, 4)
  st.width = 700
  pcall(ns.ToggleUI); W.tick(0.05, 6)
  ACD:SelectGroup("CueRules", "cooldowns", "smartTab"); W.tick(0.05, 6)
  ns.UI.NewRule(); W.tick(0.05, 10)
  layout("B narrow (700 px)")
  pcall(ns.ToggleUI); W.tick(0.1, 4)
  st.width = w0
  pcall(ns.ToggleUI); W.tick(0.05, 6)
end)

section("C switch to Drafts", function()
  ACD:SelectGroup("CueRules", "cooldowns", "draftsTab"); W.tick(0.3, 6)
  check("C: the picker is not drawn on Drafts", count(rows()) == 0 and header() == nil, count(rows()))
  local bx = boxes()
  check("C: the Drafts boxes show", #bx == 2, #bx)
  ACD:SelectGroup("CueRules", "cooldowns", "smartTab"); W.tick(0.3, 6)
  check("C: back on Smart Categories the picker is gone (forgotten when Drafts opened)", count(rows()) == 0 and header() == nil, count(rows()))
end)

section("D + New Rule on Drafts", function()
  ACD:SelectGroup("CueRules", "cooldowns", "draftsTab"); W.tick(0.1, 6)
  ns.UI.NewRule(); W.tick(0.1, 10)
  local sub = ns.CurrentSub and ns.CurrentSub()
  check("D: the picker opens on Drafts (New Rule keeps its tab)", sub == "draftsTab" and count(rows()) == 10 and header() ~= nil, tostring(sub) .. " / " .. count(rows()))
  check("D: the Drafts boxes hide while it is open (nothing drawn over them)", sub == "draftsTab" and #boxes() == 0, tostring(sub) .. " / " .. #boxes())
  ACD:SelectGroup("CueRules", "cooldowns", "enabledTab"); W.tick(0.3, 6)
  ACD:SelectGroup("CueRules", "cooldowns", "draftsTab"); W.tick(0.3, 6)
  check("D: another sub-tab and back: the picker is gone and the Drafts boxes are back", count(rows()) == 0 and #boxes() == 2, count(rows()) .. " / " .. #boxes())
end)

section("E window closed", function()
  ACD:SelectGroup("CueRules", "cooldowns", "smartTab"); W.tick(0.1, 6)
  ns.UI.NewRule(); W.tick(0.1, 10)
  check("E: the picker is open before closing", count(rows()) == 10)
  pcall(ns.ToggleUI); W.tick(0.3, 6)
  pcall(ns.ToggleUI); W.tick(0.1, 10)
  ACD:SelectGroup("CueRules", "cooldowns", "smartTab"); W.tick(0.1, 6)
  check("E: reopened, the picker is gone", count(rows()) == 0 and header() == nil, count(rows()))
end)

section("F the walkthrough (debug-w1, V22)", function()
  local QA = rawget(_G, "XayaUI_DevQA")
  local d = QA and QA.walks and QA.walks["debug-w1"]
  check("F: the walkthrough is registered with pre-fill for B280-B283", d ~= nil and d.prefill == true and d.qa == "B280, B281, B282, B283" and #d.steps == 5)
  if not d then return end
  for i = 1, 4 do check("F: step " .. i .. " has a check", type(d.steps[i].check) == "function") end
  check("F: the last step is Done, no verdict", d.steps[5].done == true and d.steps[5].noVerdict == true)
  local v1, n1 = d.steps[1].check()
  -- the stand-in's spec API (tests/harness/world.lua) has no Devourer: a verdict either way, and the game's answers in the note
  check("F: step 1 reads the Specialization list and the game's answers", type(v1) == "boolean" and tostring(n1):find("GetNumSpecializationsForClassID(12) = ", 1, true) ~= nil, n1)
  local v2, n2 = d.steps[2].check()
  check("F: step 2 judges only a rule that shows the warning (none here: no verdict, says why)", v2 == nil and tostring(n2):find("no rule shows", 1, true) ~= nil, n2)
  d.steps[3].setup(); W.tick(0.1, 10)
  local v3, n3 = d.steps[3].check()
  check("F: step 3 opens the picker and finds Import lined up with Dynamic Group", v3 == true, n3)
  d.steps[4].setup(); W.tick(0.3, 6)
  local v4, n4 = d.steps[4].check()
  check("F: step 4 opens Drafts and finds no picker there", v4 == true, n4)
end)
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = list(folders)   # Dev Assist on: section F runs the walkthrough
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
