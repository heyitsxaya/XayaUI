#!/usr/bin/env python3
"""The version pane (Options 0.6.56; Xaya 2026-11-06, REQUEST-LOG #86-#88 and A9 S9-1..S9-3).

What she sees: clicking the version text in the settings window's bottom-left corner opens a pane above the settings window with
two tabs, Patch Notes (What's New, then one entry per landing) and Info (Version info, Readme, Help (FAQ), Credits +
Acknowledgements), each with its sections on the left. The ? in the settings window's title bar (beside collapse and X) and in the
pane's own title bar opens Info > Help (FAQ). The pane can be dragged and remembers where it was left, collapses to its title bar,
and Esc closes it before the settings window. Addon Info and Settings > Acknowledgements are gone from the settings tree.
The pane's text is generated from PATCH-NOTES.md, docs/README-INGAME.md and docs/HELP-FAQ.md; this test fails while the
generated XayaUI_Options/InfoPaneData.lua and the markdown disagree.
Run: python3 tests/info_pane_run.py"""
import os, re, subprocess, sys
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
local function contentText()
  local btns = {}
  for _, b in ipairs(f.btnPool.list) do btns[#btns + 1] = b.text end
  for i, b in ipairs(f.btnPool.list) do if not b:IsShown() then btns[i] = { IsShown = function() return false end } end end
  return shown(f.fsPool.list) .. "\n" .. shown(btns)
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
check("What's New shows new features grouped by addon line (e.g. Quality of Life 0.7.x, Shopping List)",
  txt:find("Quality of Life 0.7.x", 1, true) ~= nil and txt:find("Shopping List", 1, true) ~= nil, txt:sub(1, 200))
check("What's New leaves out fixes (\"Fixed an issue ...\")", txt:find("Fixed an issue", 1, true) == nil)

-- a dated entry: the full notes, blue-post style (Developers' notes kept)
-- (the landing is found by its content, not by position: the newest landing changes with every push)
local pickedLanding = "p1"
for i = 1, __N__ do
  P.Select("patch", "p" .. i)
  local t = contentText()
  if t:find("Fixed an issue", 1, true) and t:find("/xui shop", 1, true) then pickedLanding = "p" .. i; break end
end
P.Select("patch", pickedLanding)
txt = contentText()
check("a landing shows its full notes, fixes included", txt:find("Fixed an issue", 1, true) ~= nil and txt:find("Developers' notes", 1, true) ~= nil)
check("**bold** and `commands` are coloured, not shown with their markers",
  txt:find("**", 1, true) == nil and txt:find("`", 1, true) == nil and txt:find("/xui shop", 1, true) ~= nil)

-- Info tab
for _, b in ipairs(f.tabs) do if b.key == "info" then b:Click() end end
nl = navLabels()
check("Info lists Version info, Readme, Help (FAQ), Credits + Acknowledgements",
  table.concat(nl, "|") == "Version info|Readme|Help (FAQ)|Credits + Acknowledgements", table.concat(nl, "|"))
txt = contentText()
local ver = C_AddOns.GetAddOnMetadata("XayaUI", "Version")
check("Version info shows the XayaUI version (what Addon Info showed)", txt:find("v" .. ver, 1, true) ~= nil and txt:find("Last updated:", 1, true) ~= nil)
check("Version info points to the credits' new place", txt:find("Info > Credits + Acknowledgements", 1, true) ~= nil)
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
check("Credits + Acknowledgements has every credit, as before", #missing == 0, table.concat(missing, "; "))
check("...with its heading, intro and section counts", txt:find("Credits and attribution", 1, true) and txt:find("stands on other people's work", 1, true)
  and txt:find("CODE", 1, true) and txt:find("(3)", 1, true))
local hdr
for _, b in ipairs(f.btnPool.list) do if b:IsShown() and tostring(b.text:GetText()):find("CODE", 1, true) then hdr = b end end
check("a section header collapses its credits", hdr ~= nil)
if hdr then
  hdr:Click(); txt = contentText()
  check("...collapsed: its credits are hidden, the others stay", not txt:find("LibStub", 1, true) and txt:find("EllesmereUI", 1, true))
  for _, b in ipairs(f.btnPool.list) do if b:IsShown() and tostring(b.text:GetText()):find("CODE", 1, true) then b:Click() end end
  check("...and opens again", contentText():find("LibStub", 1, true) ~= nil)
end

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
    "__CREDITS__", ", ".join('"%s"' % n for n in CREDIT_NAMES))   # already escaped as Lua source


def data_in_sync():
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "build_info_pane_data.py"), "--check"],
                       capture_output=True, text=True)
    return r.returncode == 0, (r.stdout + r.stderr).strip()


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
    ok, msg = data_in_sync()
    results.append(("InfoPaneData.lua matches PATCH-NOTES.md, README-INGAME.md, HELP-FAQ.md" + ("" if ok else "  [" + msg + "]"), ok))
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    kb, loaded = data_memory_kb(L)
    results.append(("the generated text loads; it adds %.1f KB of Lua memory once the settings window addon loads" % kb, loaded and kb < 120))
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
