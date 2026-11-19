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
(bundle 1 round 9, REQUEST-LOG A23 SD-69, her answer "Recent notes only in game (Recommended)": "In-game pane shows the last few
versions' notes plus a pointer to the full file; stays under 200 KB with room to grow") The pane holds only the newest KEEP landings
of PATCH-NOTES.md, in the file's order, then an "Older notes" entry (and a last What's New paragraph) naming PATCH-NOTES.md and the
repository link; no older landing is in the pane. Its memory is measured from the file's text under a fixed chunk name, so the reading
no longer depends on where the checkout lies (round 8: 200.1 KB in one checkout, a pass in another); the cap stays 200 KB and the
reading must also stay under main's 190 KB target (b1bef6e9, A24 #12). Negative control: the round 8 data (every landing, no pointer)
fails the landing list, the pointer and the target checks.
(bundle 1 round 11a, docs) R11a: what the pane and the guides it points to tell the player matches the code after round 11a. Every
quoted line is read from the Lua or .toc file that prints or shows it, so a document that drifts from the code fails here:
  E  SD-139 (her answers "Errors and warnings only", "Always save errors", "Yes, same file"): the pane's Readme and Help, and USER-GUIDE
     12.14, say errors and warnings are saved whether or not Advanced Debugging is on, ordinary messages never, and where to see them
     (/xui bug, after Advanced Debugging and a /reload, because /xui bug is a debug tool); every code in DebugRecord.lua's
     ns.ERROR_CODES has a row in USER-GUIDE's table; QA B439 quotes the test warning's chat line, the /xui bug line with Advanced
     Debugging off, the Debug report count and the bug report lines exactly as the code builds them.
  S  SD-146 ("Repeat the reason each time (Recommended)") and the round 11a /xui stats words: USER-GUIDE 12.12a and QA B440 quote the
     loader's reason lines and its help line; no document says only the first open says why.
  A  AddOns list: QA B441 quotes both Bonus .toc Notes lines exactly, with their versions; no player document repeats the old Notes.
  V  Versions (V10, V17, V18): each addon is above its round 10 version, X-Date 2026-11-18; PATCH-NOTES' first entry, the pane, QA
     B401 and WHATS-NEW section 17 carry those versions; the pane names the round 11a changes.
  K  (repair 1) Files that stop with a Lua error: no player text says more than the code does ("nothing of it is used", "counts as
     not loaded"), and PATCH-NOTES' Bonus entry, the pane, USER-GUIDE 12.12a and WHATS-NEW 17 state each limit the code still has
     (A: StatCalculator.lua's start-up does not read FilesErrored; B: no end-of-file mark in every calculator file) and none it has
     fixed. Both gaps are read from the code, so the check flips when the statcalc follow-up lands. On the documents before repair 1
     (scratchpad r11apre-docs-repair1) K1 and K2 fail.
  D  No document path the pane or a player guide names is missing from this checkout (no pointer at a working doc that left, SD-140).
  Negative control: on the documents before the round 11a docs unit (scratchpad r11apre-docs) checks in E, S, A and V fail.
Run: python3 tests/info_pane_run.py"""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

# (round 7 docs) HTML comments are left out, as tools/build_info_pane_data.py leaves them out (strip_comments): a landing held in a
# comment in PATCH-NOTES.md is not in the pane, so it is not counted here either
PATCH = re.sub(r"<!--.*?-->", "", open(os.path.join(ROOT, "PATCH-NOTES.md"), encoding="utf-8").read(), flags=re.S)
ALL_LANDINGS = re.findall(r"^## (\d{4}-\d{2}-\d{2}) — (.+?)\s*$", PATCH, re.M)
KEEP = 5   # SD-69: the newest landings shown in game ("few" = 5 is the docs unit's reading of her words, not her number). It must match
           # KEEP_LANDINGS in the build tool's round 9 patch, which is NOT on qa-installer-branch yet (pending; the patch is kept with
           # Xaya's private developer notes since round 11a, SD-140)
TRIMMED = len(ALL_LANDINGS) > KEEP
N_LANDINGS = min(len(ALL_LANDINGS), KEEP) + (1 if TRIMMED else 0)   # + the "Older notes" entry
FIRST_DATE = ALL_LANDINGS[0][0]
KEPT = ALL_LANDINGS[:KEEP]
DROPPED_TITLES = [t for _, t in ALL_LANDINGS[KEEP:] if t not in [k[1] for k in KEPT]]
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
-- (round 9, SD-69) recent notes only: the newest landings in the file's order, then "Older notes" pointing to the full file
local wantNav = { __KEPT__ }
local navOk = #wantNav > 0
for i, d in ipairs(wantNav) do if nl[1 + i] ~= d then navOk = false end end
check("SD-69: the pane lists only the newest __KEEP__ landings of PATCH-NOTES.md, in its order", navOk, table.concat(nl, ", "))
local D = ns.InfoPaneData
local dropped, droppedHit = { __DROPPED__ }, {}
for _, l in ipairs(D.patches) do for _, t in ipairs(dropped) do if l.title == t then droppedHit[#droppedHit + 1] = t end end end
check("SD-69: no older landing is in the pane (" .. #dropped .. " older titles looked for)", #droppedHit == 0, table.concat(droppedHit, "; "))
if __TRIMMED__ then
  check("SD-69: the last entry is \"Older notes\"", nl[#nl] == "Older notes", nl[#nl])
  P.Select("patch", "p" .. __N__)
  local ot = contentText()
  check("SD-69: \"Older notes\" points to the full file (PATCH-NOTES.md and the repository link)",
    ot:find("PATCH-NOTES.md", 1, true) ~= nil and ot:find("https://github.com/heyitsxaya/XayaUI", 1, true) ~= nil, ot:sub(1, 200))
  P.Select("patch", "whatsnew")
  local wt = contentText()
  check("SD-69: What's New ends by pointing to the full file too", wt:find("PATCH-NOTES.md", 1, true) ~= nil, wt:sub(-200))
end
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
    "__KEEP__", str(KEEP)).replace("__TRIMMED__", "true" if TRIMMED else "false").replace(
    "__KEPT__", ", ".join('"%s"' % d for d, _ in KEPT)).replace(
    "__DROPPED__", ", ".join('"%s"' % t.replace("\\", "\\\\").replace('"', '\\"') for t in DROPPED_TITLES)).replace(
    "__CREDITS__", ", ".join('"%s"' % n for n in CREDIT_NAMES)).replace("__NCRED__", str(len(CREDIT_NAMES)))


def data_memory_kb_by_path(L, path):
    """(round 9 docs repair) The round 8 way, kept only as a control: loadfile(path), so the chunk name is the file's own path."""
    f = L.eval('''function(path)
        collectgarbage("collect"); local before = collectgarbage("count")
        local ns = {}
        local chunk = assert(loadfile(path)); chunk("XayaUI_Options", ns)
        collectgarbage("collect"); local after = collectgarbage("count")
        return after - before, ns.InfoPaneData ~= nil
    end''')
    return f(path)


def data_memory_kb(L, path=None):
    """Lua memory the generated text adds once XayaUI_Options loads (measured, Lua 5.1 via lupa).
    (round 9, SD-69) The text is loaded under one fixed chunk name, the same on every machine, not under this checkout's path: Lua
    keeps the chunk name as a string in memory, so loadfile(path) counted the path's own length and the reading moved with where the
    checkout lies (round 8: 200.1 KB from a long scratch path)."""
    f = L.eval('''function(src)
        collectgarbage("collect"); local before = collectgarbage("count")
        local ns = {}
        local chunk = assert(loadstring(src, "@Interface/AddOns/XayaUI_Options/InfoPaneData.lua")); chunk("XayaUI_Options", ns)
        collectgarbage("collect"); local after = collectgarbage("count")
        return after - before, ns.InfoPaneData ~= nil
    end''')
    with open(path or os.path.join(ROOT, "XayaUI_Options", "InfoPaneData.lua"), encoding="utf-8") as fh:
        src = fh.read()
    kb, ok = f(src)
    return kb, ok


def _read(rel):
    p = os.path.join(ROOT, rel)
    if not os.path.exists(p):
        return ""
    with open(p, encoding="utf-8") as fh:
        return fh.read()


def _lua(src, pattern):
    m = re.search(pattern, src, re.S)
    return m.group(1) if m else None


def _vkey(v):
    return tuple(int(x) for x in v.split(".")) if v else (0,)


def _toc(folder, key):
    m = re.search(r"^## %s:\s*(.+?)\s*$" % key, _read("%s/%s.toc" % (folder, folder)), re.M)
    return m.group(1) if m else None


def _steps(qa):
    out = {}
    for m in re.finditer(r"^- \[ \] \*\*B(\d+)\.\*\*(.*?)(?=^- \[ \]|^#|\Z)", qa, re.M | re.S):
        out[int(m.group(1))] = m.group(2)
    return out


# round 10's .toc versions (the round 10 docs unit's lines); round 11a changed code in every one of these addons
ROUND10 = {"XayaUI": "0.6.87", "XayaUI_Options": "0.6.110", "XayaUI_Rules": "0.7.2", "XayaUI_Debug": "0.7.1",
           "XayaUI_Bonus": "0.6.47", "XayaUI_Bonus_StatCalculator": "0.6.47"}
R11A_DATE = "2026-11-18"


def round11a_checks():
    """(bundle 1 round 11a, docs) E, S, A, V and D of the docstring. Returns (name, ok) pairs."""
    R = []

    def check(name, ok, extra=""):
        R.append((name + ("" if ok else "  [%s]" % (str(extra)[:300],)), bool(ok)))

    ipd = _read("XayaUI_Options/InfoPaneData.lua")
    ug, faq, rd = _read("docs/USER-GUIDE.md"), _read("docs/HELP-FAQ.md"), _read("docs/README-INGAME.md")
    qa, wn, readme = _read("docs/QA-CHECKLIST.md"), _read("docs/WHATS-NEW.md"), _read("README.md")
    pn = re.sub(r"<!--.*?-->", "", _read("PATCH-NOTES.md"), flags=re.S)
    st = _steps(qa)
    dr, core, cons = _read("XayaUI/DebugRecord.lua"), _read("XayaUI/Core.lua"), _read("XayaUI/Console.lua")
    opts, bug, loader = _read("XayaUI_Options/Options.lua"), _read("XayaUI_Debug/BugReport.lua"), _read("XayaUI_Bonus/StatCalculatorLoader.lua")
    prefix = "XayaUI: " if 'print("|cff33ccffXayaUI|r: " .. text)' in core else None   # what ns.Print puts before every line

    # ---------------- E: SD-139, errors and warnings always saved
    # the pane (what the player reads in game): the Readme's Debugging bullet and the Help question
    deb = _lua(ipd, r'\{ "b", 1, "(\*\*Debugging\.\*\*[^"]*)" \}') or ""
    check("E1 the pane's Debugging bullet: errors and warnings are saved either way, never ordinary messages; /xui bug lists them",
          all(w in deb for w in ("saves its own errors and warnings either way", "never its ordinary messages",
                                 "`/xui bug` lists them")) and "records what is needed" not in ipd, deb[:160])
    qa_faq = _lua(ipd, r'\{ "h3", "Does XayaUI save its error messages\?" \},\s*\{ "p", "([^"]+)" \}') or ""
    check("E2 the pane's Help answers 'Does XayaUI save its error messages?': saved whether or not Advanced Debugging is on, ordinary "
          "messages not, and how to see them (Advanced Debugging, /reload, /xui bug)",
          all(w in qa_faq for w in ("whether or not Advanced Debugging is on", "Ordinary messages are not saved", "type `/reload`",
                                    "`/xui bug`")), qa_faq[:160])
    # /xui bug is a debug tool: while the tools are not loaded it prints DebugToolsNeeded's line (Console.lua); so a guide that sends the
    # player to /xui bug for the saved errors must say to turn on Advanced Debugging and /reload first
    bug_what = _lua(cons, r'function ns\.ShowBugReport\(\) ns\.DebugToolsNeeded\("([^"]+)"\) end')
    needs = _lua(dr, r'ns\.Print\(what \.\. "( needs Advanced Debugging: [^"]+)"\)')
    where = _lua(ug, r"(- \*\*Where to see them:\*\*[^\n]+)") or ""
    check("E3 USER-GUIDE 12.14 says where to see them: Advanced Debugging and /reload, then /xui bug or /xui report (core's /xui bug "
          "needs the tools: %r)" % ((bug_what or "") + (needs or ""))[:80],
          bug_what and needs and where.find("turn on Advanced Debugging") >= 0 and where.find("`/reload`") >= 0
          and where.find("`/reload`") < where.find("`/xui bug`") and "Errors saved while it was off are there too" in where, where[:160])
    sec = ug[ug.find("### 12.14"):ug.find("\n### ", ug.find("### 12.14") + 5)]
    check("E4 USER-GUIDE 12.14: saved whether or not Advanced Debugging is on; an ordinary message is never saved; no 'Off: nothing is "
          "recorded' and no 'the recording starts or stops at once'",
          "whether or not Advanced Debugging is on" in sec and "An ordinary XayaUI message is never saved" in sec
          and "nothing is recorded" not in sec and "the recording starts or stops at once" not in sec)
    codes = re.findall(r'\{ code = "(XUI-[EW]\d{3})", kind = "(error|warning)"', dr)
    rows = set(re.findall(r"^\| (XUI-[EW]\d{3}) \|", sec, re.M))
    check("E5 every code in DebugRecord.lua's ns.ERROR_CODES (%d) has a row in USER-GUIDE 12.14's table" % len(codes),
          codes and not [c for c, _ in codes if c not in rows], [c for c, _ in codes if c not in rows])
    # QA B439: the test warning, built from the code
    b439 = st.get(439, "")
    run = re.search(r'`(/run XayaUI_NS\.PrintWarning\("(XUI-W\d{3})", "([^"]+)"\))`', b439)
    kinds = dict(codes)
    wtext = _lua(dr, r'\{ code = "%s", kind = "warning", text = "([^"]+)" \}' % (run.group(2) if run else "none"))
    nowf = _lua(opts, r'\("XayaUI records its own errors and warnings[^"]*?(Now: %d error%s and %d warning%s \(%d times in all\)\.)')
    bugf = _lua(bug, r'add\(\("(Errors and warnings from XayaUI: %d occurrence\(s\), %d different \(codes: /xui report\))"\)')
    ver = _toc("XayaUI", "Version")
    pw = "function ns.PrintWarning(" in core and "XayaUI_NS = ns" in core
    exp = []
    if run and prefix and nowf and bugf and wtext and bug_what and needs:
        exp = ['"%s%s"' % (prefix, run.group(3)),                                   # the warning's chat line (ns.Print)
               '"%s%s%s"' % (prefix, bug_what, needs),                               # /xui bug with Advanced Debugging off
               '"%s"' % (nowf % (0, "s", 0, "s", 0)), '"%s"' % (nowf % (0, "s", 1, "", 1)),   # Settings > Debugging > Debug report
               '"%s"' % (bugf % (1, 1)), '"[1] %s x1"' % run.group(2), '"version %s"' % ver,   # the bug report (BugReport.lua)
               '"%s: %s"' % (wtext, run.group(3))]                                   # the saved message (ns.RecordWarn)
    check("E6 QA B439 (SD-139, Advanced Debugging off): a /run line under 256 characters calls ns.PrintWarning with a warning code, and "
          "the step quotes what the code prints and saves",
          run and pw and kinds.get(run.group(2)) == "warning" and len(run.group(1)) <= 255 and exp
          and not [e for e in exp if e not in b439] and "`/reload`" in b439 and "Untick **Advanced Debugging**" in b439,
          [e for e in exp if e not in b439] or b439[:120])

    # ---------------- S: SD-146 and the /xui stats words
    say_dis = _lua(loader, r'disabled = \{ status = WHY_DISABLED,\s*say = "([^"]+)" \}')
    why_dis = _lua(loader, r'local WHY_DISABLED = "([^"]+)"')
    help_l = _lua(loader, r'local HELP = "([^"]+)"')
    repeats = "if not ok then if loadTried then SayWhy() end; return end" in loader   # OpenOrToggle: every try after a failed load
    unknown = re.search(r'-- "help", and \(round 11a\) any word it does not know.*?\n\s*ns\.Print\(HELP\)\nend', loader, re.S)
    s12 = ug[ug.find("### 12.12a"):ug.find("### 12.12 ")]
    cant = _lua(s12, r"(- \*\*If it cannot load\*\*[^\n]+)") or ""
    check("S1 USER-GUIDE 12.12a: while it cannot load, every /xui stats prints the same one line (SD-146; the loader repeats it: %s); "
          "the three causes; the loader's reason and status lines quoted" % bool(repeats),
          repeats and say_dis and why_dis and prefix and "every `/xui stats` prints the same one line" in cant
          and all(w in cant for w in ("switched off in the game's AddOns list", "its folder is missing", "stopped with a Lua error"))
          and ('"%s%s"' % (prefix, say_dis)) in cant and ('"%s%s"' % (prefix, why_dis)) in cant
          and "the first open prints one line" not in ug, cant[:160])
    check("S2 USER-GUIDE 12.12a: /xui stats help and any other word print the loader's help line and open or close nothing",
          unknown and help_l and prefix and ('"%s%s"' % (prefix, help_l)) in s12 and "any other word after `/xui stats`" in s12
          and "opens or closes nothing" in s12)
    b440 = st.get(440, "")
    check("S3 QA B440 (SD-146): /xui stats twice while switched off in the AddOns list gives the same line both times; status, a typo "
          "and an unknown word with the panel open are quoted from the loader",
          say_dis and why_dis and help_l and prefix and b440.count("`/xui stats`") >= 2 and "both times the same one line" in b440
          and ('"%s%s"' % (prefix, say_dis)) in b440 and ('"%s%s"' % (prefix, why_dis)) in b440
          and ('"%s%s"' % (prefix, help_l)) in b440 and "`/xui stats stauts`" in b440 and "the panel stays open" in b440, b440[:120])
    check("S4 the pane's Readme: /xui stats says why each time it cannot load; HELP-FAQ has the question for it",
          "If it cannot load, it says why each time you type it." in ipd
          and "### /xui stats keeps saying the Stat Calculator could not load." in faq and "every time you try" in faq)

    # ---------------- A: the AddOns list's descriptions (the .toc Notes)
    nb, ns_ = _toc("XayaUI_Bonus", "Notes"), _toc("XayaUI_Bonus_StatCalculator", "Notes")
    b441 = st.get(441, "")
    check("A1 QA B441 quotes both Bonus .toc Notes exactly, with their .toc versions",
          nb and ns_ and ('"%s"' % nb) in b441 and ('"%s"' % ns_) in b441
          and b441.count("version %s" % _toc("XayaUI_Bonus", "Version")) >= 1
          and ("version %s" % _toc("XayaUI_Bonus_StatCalculator", "Version")) in b441, b441[:120])
    old = ("once per reload, only while the Stat Calculator is on", "loaded only while it is on")
    players = {"USER-GUIDE": ug, "HELP-FAQ": faq, "README-INGAME": rd, "README.md": readme, "PATCH-NOTES": pn, "pane": ipd}
    stale = ["%s: %s" % (n, w) for n, t in players.items() for w in old if w in t]
    check("A2 the Notes say it loads the first time you open it; no player document repeats the old Notes", nb and ns_
          and "loads the first time you open it" in nb and "Loads the first time you open it, never at login" in ns_ and not stale, stale)

    # ---------------- V: versions and notes (V10, V17, V18)
    tv = {f: _toc(f, "Version") for f in ROUND10}
    low = ["%s %s" % (f, v) for f, v in tv.items() if _vkey(v) <= _vkey(ROUND10[f])]
    dates = ["%s %s" % (f, _toc(f, "X-Date")) for f in ROUND10 if _toc(f, "X-Date") != R11A_DATE]
    check("V1 every addon round 11a changed is above its round 10 version, X-Date %s" % R11A_DATE, not low and not dates, low + dates)
    heads = re.findall(r"^## (\d{4}-\d{2}-\d{2}) — (.+?)\s*$", pn, re.M)
    entry = (re.split(r"^## \d{4}-\d{2}-\d{2} — .*$", pn, flags=re.M) + ["", ""])[1]
    hn = {"XayaUI": "XayaUI", "XayaUI_Options": "Options", "XayaUI_Rules": "Rules", "XayaUI_Bonus": "Bonus Features",
          "XayaUI_Bonus_StatCalculator": "Bonus Features"}
    miss = ["### %s %s" % (h, tv[f]) for f, h in hn.items() if ("### %s %s\n" % (h, tv[f])) not in entry]
    check("V2 PATCH-NOTES' first entry is bundle 1, dated %s, with a heading per changed addon at its .toc version" % R11A_DATE,
          heads and heads[0] == (R11A_DATE, "Rules Fix Bundle 1") and not miss, (heads[:1], miss))
    pane_miss = ["%s %s" % (h, tv[f]) for f, h in hn.items() if ('"%s %s"' % (h, tv[f])) not in ipd]
    check("V3 the pane shows those versions as its newest entry's headings", not pane_miss, pane_miss)
    must = ["saves every error and warning it prints in chat", "says why every time you type it", "now prints its help line",
            "The AddOns list now describes XayaUI Bonus Features and its Stat Calculator correctly"]
    check("V4 the bundle 1 entry, and so the pane, names the round 11a changes", not [w for w in must if w not in entry or w not in ipd],
          [w for w in must if w not in entry or w not in ipd])
    b401 = st.get(401, "")
    check("V5 QA B401 names every addon's .toc version", all(v and v in b401 for v in tv.values()), [v for v in tv.values() if v not in b401])
    s17 = wn[wn.find("## 17. Rules fix bundle 1, round 11a"):]
    wv = ["XayaUI %s" % tv["XayaUI"], "Options %s" % tv["XayaUI_Options"], "Rules %s" % tv["XayaUI_Rules"],
          "XayaUI Debug %s" % tv["XayaUI_Debug"], "Bonus Features %s" % tv["XayaUI_Bonus"]]
    check("V6 WHATS-NEW section 17 covers round 11a with every version and its QA steps (V18)",
          "## 17. Rules fix bundle 1, round 11a" in wn and not [v for v in wv if v not in s17.replace("\n", " ")]
          and "B439 to B441" in s17, [v for v in wv if v not in s17.replace("\n", " ")])

    # ---------------- K: the third cause (files that stop with a Lua error) is told with the limits the code still has
    # (round 11a docs repair 1) The loader counts such a load as not loaded (SD-105 gap, statcalc unit), but two limits remain in code:
    #   gap A: StatCalculator.lua's own start-up does not stand down after an earlier file stopped (no FilesErrored read in it), so
    #          opening the character window can still raise a Lua error; read from the code, so the check flips when that is built.
    #   gap B: the loader finds a stop through the game's error handler; if another addon makes seterrorhandler do nothing, only the
    #          service probe is left, and a stop in StatMath.lua or late in StatCalculator.lua is missed. Closed only when every
    #          calculator file ends with its own Provide mark (the end-of-file marks the statcalc reviews proposed).
    calc_dir = "XayaUI_Bonus_StatCalculator"
    calc_src = _read(calc_dir + "/StatCalculator.lua")
    gap_a = bool(calc_src) and "FilesErrored" not in calc_src
    lasts = []
    for f in ("StatMath.lua", "StatModel.lua", "StatCalculator.lua"):
        code = [ln for ln in _read("%s/%s" % (calc_dir, f)).splitlines() if ln.strip() and not ln.strip().startswith("--")]
        lasts.append(bool(code) and "Provide(" in code[-1])
    gap_b = "seterrorhandler" in loader and not all(lasts)
    errored = re.compile(r"stop(?:s|ped)? with a Lua error")
    over = re.compile(r"nothing of it is used|none of it is used|nothing of it runs|counts as not loaded|is never used|always caught"
                      r"|catches every", re.I)
    LIMIT_A = "opening the character window can still show a Lua error"
    LIMIT_B = "if another addon stops other addons from seeing Lua errors"

    def blocks(text):
        """A guide's paragraphs and list items, each on one line (wrapped lines joined)."""
        out = []
        for chunk in re.split(r"\n\s*\n", text):
            for item in re.split(r"\n(?=\s{0,3}(?:[-*] |#))", chunk):
                out.append(" ".join(item.split()))
        return out
    pane_strings = [" ".join(s.split()) for s in re.findall(r'"((?:[^"\\\n]|\\.)*)"', ipd)]
    docs_blocks = {"USER-GUIDE": blocks(ug), "HELP-FAQ": blocks(faq), "README-INGAME": blocks(rd), "README.md": blocks(readme),
                   "PATCH-NOTES": blocks(pn), "WHATS-NEW": blocks(wn), "pane": pane_strings}
    claims = ["%s: %s" % (n, b[:140]) for n, bl in docs_blocks.items() for b in bl
              if errored.search(b) and over.search(b) and (gap_a or gap_b)]
    check("K1 no player document or pane text says more than the code does about files that stop with a Lua error (open gaps: A %s, "
          "B %s): no 'nothing of it is used' or 'counts as not loaded'" % (gap_a, gap_b), not claims, claims)
    bonus = (re.split(r"^### ", entry, flags=re.M) or [""])
    bonus = next((s for s in bonus if s.startswith("Bonus Features ")), "")
    places = {"PATCH-NOTES bundle 1 Bonus Features": " ".join(bonus.split()), "USER-GUIDE 12.12a": " ".join(s12.split()),
              "WHATS-NEW 17": " ".join(s17[:s17.find("\n## ")].split()) if "\n## " in s17 else " ".join(s17.split()),
              "pane": " ".join(p for p in pane_strings if errored.search(p) and "Stat Calculator" in p and "minimap row" in p)}
    wrong = []
    for n, t in places.items():
        if not errored.search(t):
            wrong.append("%s: does not name the third cause" % n)
            continue
        for gap, mark in ((gap_a, LIMIT_A), (gap_b, LIMIT_B)):
            if gap and mark not in t:
                wrong.append("%s: missing %r" % (n, mark))
            if not gap and mark in t:
                wrong.append("%s: still says %r, which the code has fixed" % (n, mark))
    check("K2 PATCH-NOTES' Bonus entry, the pane, USER-GUIDE 12.12a and WHATS-NEW 17 state each known limit the code still has, and "
          "none the code has fixed (A: the calculator's start-up still runs after a stop; B: an addon that blocks error handlers)",
          not wrong, wrong)

    # ---------------- D: no pointer at a document that is not here (SD-140: the working docs left this repo)
    named = {}
    for n, t in list(players.items()) + [("QA-CHECKLIST", qa), ("WHATS-NEW", wn)]:
        for path in set(re.findall(r"\bdocs/[\w./-]+\.(?:md|json|html|png)", t)):
            if not os.path.exists(os.path.join(ROOT, path)):
                named.setdefault(n, []).append(path)
    check("D1 every docs/... path the pane and the player guides name exists in this checkout", not named, named)
    return R


def main():
    results = round11a_checks()
    folders = H.find_addons()
    enabled = list(folders)
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    kb, loaded = data_memory_kb(L)
    # (round 9, SD-69 "stays under 200 KB with room to grow") main's own target for this file (b1bef6e9, A24 #12): under 190 KB
    results.append(("SD-69: it stays under main's 190 KB target (%.1f KB; room under the 200 KB cap %.1f KB)" % (kb, 200 - kb),
                    loaded and kb < 190))
    # the reading does not depend on where the checkout lies: the same text copied under a long path reads the same
    import tempfile, shutil
    tmp = tempfile.mkdtemp()
    deep = os.path.join(tmp, *(["a_rather_long_folder_name_for_this_check"] * 6))
    os.makedirs(deep)
    shutil.copy(os.path.join(ROOT, "XayaUI_Options", "InfoPaneData.lua"), os.path.join(deep, "InfoPaneData.lua"))
    # (a new Lua state, as the first reading had: a second load into the same state shares the first one's strings and reads less)
    kb2, _ = data_memory_kb(H.lua51.LuaRuntime(unpack_returned_tuples=True), os.path.join(deep, "InfoPaneData.lua"))
    # (round 9 docs repair) control: the round 8 way (loadfile by path) does move with the path, so the two readings above being equal
    # shows the fixed chunk name removed that, and is not a reading too coarse to see a path at all
    here_p = os.path.join(ROOT, "XayaUI_Options", "InfoPaneData.lua")
    kb_p1, _ = data_memory_kb_by_path(H.lua51.LuaRuntime(unpack_returned_tuples=True), here_p)
    kb_p2, _ = data_memory_kb_by_path(H.lua51.LuaRuntime(unpack_returned_tuples=True), os.path.join(deep, "InfoPaneData.lua"))
    shutil.rmtree(tmp, ignore_errors=True)
    results.append(("control: loading by path (the round 8 way) reads more from the deeper copy (%d characters: %.3f KB; %d characters: "
                    "%.3f KB)" % (len(here_p), kb_p1, len(os.path.join(deep, "InfoPaneData.lua")), kb_p2), kb_p2 > kb_p1 + 0.05))
    results.append(("SD-69: the reading does not depend on the checkout's path (here %.1f KB; a copy %d characters deep %.1f KB)"
                    % (kb, len(deep), kb2), abs(kb - kb2) < 0.005))
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
