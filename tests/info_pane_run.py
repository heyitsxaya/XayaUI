#!/usr/bin/env python3
"""The version pane (Options 0.6.56; Xaya 2026-11-06, REQUEST-LOG #86-#88 and A9 S9-1..S9-3).

What she sees: clicking the version text in the settings window's bottom-left corner opens a pane above the settings window with
two tabs, Patch Notes (What's New, then one entry per landing) and Info (Version info, Readme, Help (FAQ), Credits +
Acknowledgements), each with its sections on the left. The ? in the settings window's title bar (beside collapse and X) and in the
pane's own title bar opens Info > Help (FAQ). The pane can be dragged and remembers where it was left, collapses to its title bar,
and Esc closes it before the settings window. Addon Info and Settings > Acknowledgements are gone from the settings tree.
The pane's text (XayaUI_Options/InfoPaneData.lua) is generated from PATCH-NOTES.md, docs/README-INGAME.md and docs/HELP-FAQ.md by
tools/build_info_pane_data.py, which is not on this branch (tools/ left it), so its --check is not run here; the landing count and
the newest landing's date below are still read from PATCH-NOTES.md.
Run: python3 tests/info_pane_run.py"""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

PATCH = open(os.path.join(ROOT, "PATCH-NOTES.md"), encoding="utf-8").read()
N_LANDINGS = len(re.findall(r"^## \d{4}-\d{2}-\d{2} — ", PATCH, re.M))
FIRST_DATE = re.search(r"^## (\d{4}-\d{2}-\d{2}) — ", PATCH, re.M).group(1)
CREDIT_NAMES = re.findall(r'\{ name = "([^"]+)"', open(os.path.join(ROOT, "XayaUI_Options", "AddonInfo.lua"), encoding="utf-8").read())

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
check("the version pane is part of the settings window addon", ns and ns.InfoPane ~= nil and ns.InfoPaneData ~= nil)
if not (ns and ns.InfoPane) then return R end
local P = ns.InfoPane
check("nothing of the pane is built before it is first opened (off costs nothing)", P.Frame() == nil and _G.XayaUIInfoPane == nil)

-- Addon Info and Settings > Acknowledgements moved into the pane ("Both move into the pane")
local built = ns.BuildOptionsTable()
check("no Addon Info page in the settings tree", built.args.info == nil)
check("no Acknowledgements page under Settings (either layout)",
  not (built.args.set and built.args.set.args.credits) and not (built.args.settings and built.args.settings.args.credits))

-- the settings window, dressed as the game opens it
local AceGUI, ACD = LibStub("AceGUI-3.0"), LibStub("AceConfigDialog-3.0")
local of = AceGUI:Create("Frame")
ACD.OpenFrames = ACD.OpenFrames or {}
ACD.OpenFrames["CueRules"] = of
of.frame:Show()
ACD:Open("CueRules", of)
W.tick(0.3, 3)
local c = of.xuiChrome
check("the settings window is dressed", c ~= nil and c.info ~= nil)
if not c then return R end
local p0, rel0, rp0 = c.info:GetPoint(1)
check("the version text stays in the bottom-left corner", p0 == "BOTTOMLEFT" and rel0 == of.frame and rp0 == "BOTTOMLEFT")

-- click the version: the pane opens on Patch Notes > What's New
c.info:Click()
local f = P.Frame()
check("clicking the version opens the pane", f ~= nil and f:IsShown())
if not f then return R end
check("the pane floats above the settings window (DIALOG over HIGH)", f:GetFrameStrata() == "DIALOG", f:GetFrameStrata())
check("it opens on Patch Notes > What's New", P.state.tab == "patch" and P.state.sel.patch == "whatsnew")
local function shown(fsList)
  local out = {}
  for _, o in ipairs(fsList) do if o:IsShown() and o.GetText and o:GetText() then out[#out + 1] = tostring(o:GetText()) end end
  return table.concat(out, "\n")
end
-- (Options 0.6.64: the credits' collapsible section rows, the only buttons in the content, are gone; REQUEST-LOG B6)
local function contentText()
  return shown(f.fsPool.list)
end
local function navLabels()
  local out = {}
  for _, b in ipairs(f.nav) do if b:IsShown() then out[#out + 1] = b.text:GetText() end end
  return out
end
local function tabNames() local t = {}; for _, b in ipairs(f.tabs) do t[#t + 1] = b.text:GetText() end; return table.concat(t, "|") end
check("two tabs: Patch Notes | Info", tabNames() == "Patch Notes|Info", tabNames())
local nl = navLabels()
check("Patch Notes lists What's New, then one entry per landing (newest first)", #nl == 1 + __N__ and nl[1] == "What's New" and nl[2] == "__FIRST__",
  table.concat(nl, ", "))
local txt = contentText()
check("What's New shows new features grouped by addon line (e.g. Bonus Features 0.6.x, Stat Calculator)",
  txt:find("Bonus Features 0.6.x", 1, true) ~= nil and txt:find("Stat Calculator", 1, true) ~= nil, txt:sub(1, 200))
-- A24 #12 (her words: "Trim old What's New text"): the notes of features retired from main are gone from the pane
-- (Chat, Quality of Life, Blizzard Reskin, Nameplates, Dev Assist, Bonus Features' tooltips / Notepad / Calculator / Utilities /
-- Data Panels). Matched on the addon lines and the feature headings ("Name  (version, date)"); a kept note may still name a retired
-- element in passing (the Element Menu's list). Negative control: fails on c4ae19b (Quality of Life 0.7.x, Shopping List listed).
local retiredHit = {}
for _, w in ipairs({ "Quality of Life 0.7.x", "Chat 0.6.x", "Blizzard Reskin 0.6.x", "Nameplates 0.2.x", "Dev Assist 0.7.x",
  "Shopping List  (", "Notepad  (", "Enhanced Tooltips  (", "Release Guard  (", "All Reskins  (", "Blizzard UI Reskin  (" }) do
  if txt:find(w, 1, true) then retiredHit[#retiredHit + 1] = w end
end
check("A24 #12: What's New lists no feature retired from main", #retiredHit == 0, table.concat(retiredHit, "; "))
check("What's New leaves out fixes (\"Fixed an issue ...\")", txt:find("Fixed an issue", 1, true) == nil)

-- a dated entry: the full notes, blue-post style (Developers' notes kept)
-- (the landing is found by its content, not by position: the newest landing changes with every push)
local pickedLanding = "p1"
for i = 1, __N__ do
  P.Select("patch", "p" .. i)
  local t = contentText()
  if t:find("Fixed an issue", 1, true) then pickedLanding = "p" .. i; break end
end
P.Select("patch", pickedLanding)
txt = contentText()
check("a landing shows its full notes, fixes included", txt:find("Fixed an issue", 1, true) ~= nil and txt:find("Developers' notes", 1, true) ~= nil)
-- (A24 #12: no landing left on main has both a fix and a command, so the markers are checked on the landing that has `/xui console`)
for i = 1, __N__ do
  P.Select("patch", "p" .. i)
  if contentText():find("/xui console", 1, true) then break end
end
txt = contentText()
check("**bold** and `commands` are colored, not shown with their markers",
  txt:find("**", 1, true) == nil and txt:find("`", 1, true) == nil and txt:find("/xui console", 1, true) ~= nil)

-- Info tab
for _, b in ipairs(f.tabs) do if b.key == "info" then b:Click() end end
nl = navLabels()
check("Info lists Version info, Readme, Help (FAQ), Credits + Acknowledgments",
  table.concat(nl, "|") == "Version info|Readme|Help (FAQ)|Credits + Acknowledgments", table.concat(nl, "|"))
txt = contentText()
local ver = C_AddOns.GetAddOnMetadata("XayaUI", "Version")
check("Version info shows the XayaUI version (what Addon Info showed)", txt:find("v" .. ver, 1, true) ~= nil and txt:find("Last updated:", 1, true) ~= nil)
check("Version info points to the credits' new place", txt:find("Info > Credits + Acknowledgments", 1, true) ~= nil)
local repoBox = false
for _, e in ipairs(f.editPool.list) do if e:IsShown() and e:GetText() == "https://github.com/heyitsxaya/XayaUI" then repoBox = true end end
check("the source code link is a copyable box", repoBox)
for _, b in ipairs(f.nav) do if b.key == "readme" then b:Click() end end
txt = contentText()
check("Readme: What XayaUI is, Getting started, Features at a glance, Slash commands (her sections 1, 2, 4, 5)",
  txt:find("What XayaUI is", 1, true) and txt:find("Getting started", 1, true) and txt:find("Features at a glance", 1, true)
  and txt:find("Slash commands", 1, true) and not txt:find("Rules in five minutes", 1, true))
P.Select("info", "credits")
txt = contentText()
local missing = {}
for _, n in ipairs({ __CREDITS__ }) do if not txt:find(n, 1, true) then missing[#missing + 1] = n end end
check("Credits + Acknowledgments has every credit, as before", #missing == 0, table.concat(missing, "; "))
-- (Options 0.6.64; REQUEST-LOG B6, reading taken; her words, ATTR-1: "increase the gutter by 10px / credits and attribution are h1 /
-- subheaders (code, ideas and design, etc) h2 / each section under a subheader should have an unrounded box with rows (no columns) on a
-- slightly less transparent background (10%)". Before: an intro paragraph, capitalised collapsible section rows with a count, one box
-- per credit. Negative control: every check below fails on Options 0.6.63.)
check("B6: the heading stays the h1, the intro paragraph is gone", txt:find("Credits and attribution", 1, true) ~= nil and txt:find("stands on other people's work", 1, true) == nil)
local recs = f.recs or {}
local function rk(kind) local o = {}; for _, r in ipairs(recs) do if r.kind == kind then o[#o + 1] = r end end; return o end
local h2s, boxes, rows = rk("h2"), rk("box"), rk("row")
local names = {}
for _, r in ipairs(h2s) do names[#names + 1] = r.text end
check("B6: each section's subheader is an h2 in normal case: Code | Ideas and design | Sounds | Game art (no capitals, no count)",
  table.concat(names, " | ") == "Code | Ideas and design | Sounds | Game art" and txt:find("CODE", 1, true) == nil and txt:find("(3)", 1, true) == nil,
  table.concat(names, " | "))
local h2font, h2seen = true, 0
for _, fs in ipairs(f.fsPool.list) do
  if fs:IsShown() and (fs:GetText() == "Code" or fs:GetText() == "Sounds") then h2seen = h2seen + 1; if fs:GetFontObject() ~= "GameFontNormalLarge" then h2font = false end end
end
check("B6: ...drawn in the pane's h2 font (GameFontNormalLarge)", h2font and h2seen == 2, h2seen)
check("B6: no section collapses any more (no arrow rows: the content has no buttons)", f.btnPool == nil)
check("B6: one box per SECTION (4), not one per credit (" .. #rows .. " credits)", #boxes == 4 and #rows == __NCRED__,
  #boxes .. " boxes, " .. #rows .. " rows")
local inside, rowsOk = true, true
for _, r in ipairs(rows) do
  local bx
  for _, b in ipairs(boxes) do if b.section == r.section then bx = b end end
  if not (bx and r.y > bx.y and r.y < bx.y + bx.h and r.x > bx.x and r.x + r.w < bx.x + bx.w) then inside = false end
end
for _, b in ipairs(boxes) do
  local n, lastY, sameX = 0, -1, nil
  for _, r in ipairs(rows) do
    if r.section == b.section then
      n = n + 1
      if r.y <= lastY then rowsOk = false end
      lastY = r.y
      sameX = sameX or r.x
      if r.x ~= sameX then rowsOk = false end
    end
  end
  if n ~= b.rows then rowsOk = false end
end
check("B6: ...every credit is a row inside its section's box", inside and #rows > 0)
check("B6: ...rows one under the other at the same x (no columns)", rowsOk and #boxes > 0)
local alphaOk = #boxes > 0
for _, b in ipairs(boxes) do if math.abs(b.alpha - math.min(1, b.paneAlpha + 0.1)) > 1e-6 then alphaOk = false end end
check("B6: ...each box's background is 10% more opaque than the pane's", alphaOk)
-- no line under a subheader: between each h2 and the top of its box no 1 px rule is shown
local rules = 0
for _, bx in ipairs(f.boxPool.list) do
  if bx.bg:IsShown() then
    local _, hgt = bx.bg:GetSize()
    if hgt == 1 then rules = rules + 1 end
  end
end
check("(guard) B6: no line under any subheader (the only rule left is the one under the h1)", rules == 1, rules)
local gapOk = #h2s == 4
for i = 2, #h2s do
  local prev
  for _, b in ipairs(boxes) do if b.section == h2s[i - 1].text then prev = b end end
  if not (prev and h2s[i].y - (prev.y + prev.h) == 30) then gapOk = false end
end
check("B6: the gutter between one section's box and the next section grows by 10 px (20 -> 30; core's gutter + 10 after the box)",
  gapOk and P.CREDITS_GUTTER == ns.UI_GUTTER + 10, P.CREDITS_GUTTER)
local corners = true
for _, bx in ipairs(f.boxPool.list) do if bx.bg:IsShown() and bx.bg.mask ~= nil then corners = false end end
check("(guard) B6: ...the boxes are square (flat textures, no rounded mask)", corners)

-- the ? in the settings window's title bar, beside collapse and X: opens Info > Help (FAQ)
check("the settings window has a ? in its title bar", c.help ~= nil and c.help:IsShown() and c.help:GetText() == "?")
if c.help then
  local hp, hrel, hrp = c.help:GetPoint(1)
  check("...just left of the collapse arrow (which is left of the X)", hp == "RIGHT" and hrel == c.arrow and hrp == "LEFT")
  P.Select("patch", "whatsnew")
  f:Hide()
  c.help:Click()
  check("...and opens the pane at Info > Help (FAQ)", f:IsShown() and P.state.tab == "info" and P.state.sel.info == "help")
  txt = contentText()
  check("the FAQ has her four groups", txt:find("Rules not firing", 1, true) and txt:find("Auras and the Cooldown Manager", 1, true)
    and txt:find("What the game won't allow", 1, true) and txt:find("Commands and reporting", 1, true))
end
P.Select("patch", "whatsnew")
f.help:Click()
check("the pane's own ? opens Info > Help (FAQ)", P.state.tab == "info" and P.state.sel.info == "help")
local hp2, hrel2 = f.help:GetPoint(1)
local cp2, crel2 = f.collapse:GetPoint(1)
check("pane title bar order: ? | collapse | X", hrel2 == f.collapse and crel2 == f.close)

-- collapse to the title bar and back
f.collapse:Click()
check("collapse: the pane shrinks to its title bar", f:GetHeight() == 28 and not f.scroll:IsShown() and not f.navScroll:IsShown() and f.close:IsShown())
f.collapse:Click()
check("expand: everything is back", f:GetHeight() == 520 and f.scroll:IsShown() and f.navScroll:IsShown())

-- moving: the title bar drags the pane, and the place is remembered
local tb = f.titleBar
check("the title bar drags the pane", f:IsMovable() and tb:GetScript("OnDragStart") ~= nil)
f:ClearAllPoints(); f:SetPoint("CENTER", UIParent, "CENTER", 120, -60)
tb:GetScript("OnDragStop")(tb)
local pos = CueRulesDB.ui and CueRulesDB.ui.infoPanePos
check("dropping it saves where it is", pos and pos[1] == 120 and pos[2] == -60, pos and (pos[1] .. "," .. pos[2]))

-- Esc closes the pane first
local prop
f.SetPropagateKeyboardInput = function(self, v) prop = v end
W.combat = false
f:GetScript("OnKeyDown")(f, "A")
check("other keys pass through to the game", prop == true and f:IsShown())
f:GetScript("OnKeyDown")(f, "ESCAPE")
check("Esc closes the pane and is kept from the game (the settings window stays open)", not f:IsShown() and prop == false and of.frame:IsShown())
local special = false
for _, n in ipairs(UISpecialFrames) do if n == "XayaUIInfoPane" then special = true end end
check("in combat Esc still closes it (UISpecialFrames), with the settings window", special)
W.combat = true
P.Open(); prop = nil
f:GetScript("OnKeyDown")(f, "ESCAPE")
check("in combat the pane does not touch key propagation (restricted)", prop == nil)
W.combat = false

-- reopening: where it was left
f:Hide()
c.info:Click()
local pp, prel, prp, px, py = f:GetPoint(1)
check("reopened where it was left", pp == "CENTER" and prel == UIParent and px == 120 and py == -60, tostring(px) .. "," .. tostring(py))

-- closing the settings window closes the pane with it
ACD.OpenFrames["CueRules"] = nil
AceGUI:Release(of)
check("releasing the settings window closes the pane and hides the ?", not f:IsShown() and not c.help:IsShown())

return R
end
'''.replace("__N__", str(N_LANDINGS)).replace("__FIRST__", FIRST_DATE).replace(
    "__CREDITS__", ", ".join('"%s"' % n for n in CREDIT_NAMES)).replace("__NCRED__", str(len(CREDIT_NAMES)))


def data_memory_kb(L):
    """Lua memory the generated text adds once XayaUI_Options loads (measured, Lua 5.1 via lupa)."""
    f = L.eval('''function(path)
        collectgarbage("collect"); local before = collectgarbage("count")
        local ns = {}
        local chunk = assert(loadfile(path)); chunk("XayaUI_Options", ns)
        collectgarbage("collect"); local after = collectgarbage("count")
        return after - before, ns.InfoPaneData ~= nil
    end''')
    kb, ok = f(os.path.join(ROOT, "XayaUI_Options", "InfoPaneData.lua"))
    return kb, ok


def main():
    results = []
    folders = H.find_addons()
    enabled = list(folders)
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    kb, loaded = data_memory_kb(L)
    results.append(("the generated text loads; it adds %.1f KB of Lua memory once the settings window addon loads" % kb, loaded and kb < 200))   # cap raised from 120 (2026-11-07): every patch note stays in game; only loaded with the settings window
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    for i in range(1, len(res) + 1):
        results.append((res[i][1], res[i][2]))
    bad = 0
    for name, good in results:
        print(("PASS " if good else "FAIL ") + name)
        bad += 0 if good else 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(results), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
