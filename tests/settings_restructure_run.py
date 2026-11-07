#!/usr/bin/env python3
"""The settings window's new top level (Options 0.6.72; REQUEST-LOG UI-23 to UI-27, Xaya 2026-11-06, her words:
  "I believe these almost exclusively belong to rules so they should be put under the rules tab and the Rules / QOL / Bonus Features /
  Reskin / Settings should be at the top level now instad"; tab label "Blizzard Reskin"; "Cog goes"; New Rule: "Rules tab's top row";
  Recycle Bin: "put into profiles instead as its own subtab"; the tab is "Profiles", "expanded as a category bucket to include all
  user-created customizations, settings, etc", "individual components can be selected to toggle").
Loads the real addons in the stand-in game, opens the window and checks what the player sees and gets:
  A the top tabs read exactly Rules | QoL | Bonus Features | Blizzard Reskin | Profiles | Settings, in that order; no Recycle Bin and
    no Import / Export top tab; Settings shows beside the others (nothing hides when it is picked); the six share the top row evenly.
  B no toolbar: the window has no xuiToolbar shown, and the content starts under the title strip (-34, not -62).
  C "+ New Rule" is a flat button at the left end of the Rules row, before Smart Categories; the tabs follow it, Auto-Generate Rules
    stays at the far right; a click starts a new rule (the type picker); the button hides when that container shows another row.
  D Profiles has the sub-tabs Import, Export, Recycle Bin; Export has one tick box per component; Recycle Bin is the old bin page.
  E the profile codec: a profile with some components round-trips; Import lists only the components the text holds; only ticked
    components are applied; settings are merged (a value the profile lacks stays); personal data never leaves (whisper-sound senders,
    calculator history, one-time upgrade flags); rules alone export as a rules string (XUI1); a pasted profile with an unknown
    component or a non-table value is cleaned; ns.UI.Settings / ns.UI.RecycleBin / ns.UI.Export open their tabs.
Negative control: A-E fail on main 7b830cf (Options 0.6.63: toolbar, "Blizzard UI Reskin", recyclebin top tab, no ns.Profile).
Run: python3 tests/settings_restructure_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

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
check("settings window addon loaded", ns and ns.BuildOptionsTable ~= nil)
if not (ns and ns.BuildOptionsTable) then return R end
local ACD = LibStub("AceConfigDialog-3.0")
local function root() return ACD.OpenFrames and ACD.OpenFrames["CueRules"] end
local function findW(w, pred)
  if not w then return nil end
  if pred(w) then return w end
  for _, c in ipairs(w.children or {}) do local f = findW(c, pred); if f then return f end end
end
local function rowWith(value) return findW(root(), function(w)
  if w.type ~= "TabGroup" then return false end
  for _, t in ipairs(w.tabs or {}) do if t:IsShown() and t.value == value then return true end end
  return false end) end
local function shownTabs(w) local l = {}; for _, t in ipairs(w and w.tabs or {}) do if t:IsShown() then l[#l + 1] = t end end; return l end

section("A: the top tabs", function()
  local built = ns.BuildOptionsTable()
  local l = {}
  for k, v in pairs(built.args) do
    local hid = v.hidden
    if type(hid) == "function" then hid = hid() end
    if type(v) == "table" and v.type == "group" and not hid then l[#l + 1] = { k = k, o = tonumber(v.order) or 0, n = v.name } end
  end
  table.sort(l, function(a, b) return a.o < b.o end)
  local names = {}
  for _, e in ipairs(l) do names[#names + 1] = e.n end
  local got = table.concat(names, " | ")
  check("A: the top tabs read Rules | QoL | Bonus Features | Blizzard Reskin | Profiles | Settings", got == "Rules | QoL | Bonus Features | Blizzard Reskin | Profiles | Settings", got)
  check("A: no Recycle Bin top tab", built.args.recyclebin == nil)
  check("A: the Profiles tab is named Profiles (not Import / Export)", built.args.profiles and built.args.profiles.name == "Profiles", built.args.profiles and built.args.profiles.name)
end)

pcall(ns.ToggleUI); W.tick(0.05, 6)
check("the window opened", root() ~= nil)

section("A/B: the window", function()
  ACD:SelectGroup("CueRules", "set", "ui"); W.tick(0.05, 6)
  local top = rowWith("set")
  check("A: Settings picked: the top row still shows Rules, QoL, Profiles beside Settings", top ~= nil and (function()
    local seen = {}
    for _, t in ipairs(shownTabs(top)) do seen[t.value] = true end
    return seen.cooldowns and seen.qol and seen.profiles and seen.set
  end)(), top and #shownTabs(top))
  if top then
    local shown = shownTabs(top)
    local fw = top.frame.width or top.frame:GetWidth()
    local each, bad = fw / #shown, {}
    for i, t in ipairs(shown) do
      local _, rel, _, x = t:GetPoint(1)
      if math.abs(t:GetWidth() - each) > 0.5 or math.abs((x or -1) - (i - 1) * each) > 0.5 or rel ~= top.frame then bad[#bad + 1] = tostring(t.value) end
    end
    check("A: the 6 top tabs share the row evenly, edge to edge", #shown == 6 and #bad == 0, #shown .. " " .. table.concat(bad, ","))
  end
  local fr = root().frame
  check("B: no toolbar is shown above the tabs", not (fr.xuiToolbar and fr.xuiToolbar:IsShown()))
  local _, _, _, _, y = root().content:GetPoint(1)
  check("B: the content starts right under the title strip (-34; it was -62 under the toolbar)", y == -34, y)
end)

section("C: + New Rule on the Rules row", function()
  ACD:SelectGroup("CueRules", "cooldowns", "smartTab"); W.tick(0.05, 6)
  local rr = rowWith("creatorTab")
  check("C: the Rules row is found", rr ~= nil)
  if not rr then return end
  local nb = rr.xuiNewRule
  check("C: a + New Rule button on it", nb ~= nil and nb:IsShown() and nb:GetText() == "+ New Rule", nb and nb:GetText())
  if not nb then return end
  local _, rel, _, x = nb:GetPoint(1)
  check("C: ...at the left end of the row", rel == rr.frame and x == 0, x)
  check("C: ...a flat button (the addon's own style), not a tab", nb.xuiFlatBtn == true and nb.value == nil)
  local smart, creator
  for _, t in ipairs(shownTabs(rr)) do if t.value == "smartTab" then smart = t elseif t.value == "creatorTab" then creator = t end end
  local _, _, _, sx = smart:GetPoint(1)
  check("C: Smart Categories starts after the button", sx >= nb:GetWidth(), ("button %s, tab at %s"):format(nb:GetWidth(), tostring(sx)))
  local fw = rr.frame.width or rr.frame:GetWidth()
  local _, _, _, cx = creator:GetPoint(1)
  check("C: Auto-Generate Rules stays at the far right", math.abs(cx + creator:GetWidth() - fw) < 0.5, cx)
  check("C: the button is not stretched (its name plus 24 px)", nb:GetWidth() <= math.floor(fw / 5) and nb:GetWidth() < smart:GetWidth() + 40, nb:GetWidth())
  local called = 0
  local realNew = ns.UI.NewRule
  ns.UI.NewRule = function() called = called + 1 end
  nb:Click()
  ns.UI.NewRule = realNew
  check("C: a click starts a new rule", called == 1, called)
  -- the same container used for another row hides it (a stand-in container with no Rules tabs, holding the same button)
  ns.SkinTabRow({ tabs = {}, frame = rr.frame, xuiNewRule = nb })
  check("C: the button hides when the container lays out another row", not nb:IsShown())
  ns.SkinTabRow(rr)
  check("C: ...and shows again on the Rules row", nb:IsShown())
end)

section("D: Profiles", function()
  local built = ns.BuildOptionsTable()
  local p = built.args.profiles
  local subs = {}
  for k, v in pairs(p.args) do if v.type == "group" then subs[#subs + 1] = { k = k, o = v.order, n = v.name } end end
  table.sort(subs, function(a, b) return a.o < b.o end)
  local s = {}
  for _, e in ipairs(subs) do s[#s + 1] = e.k .. "=" .. e.n end
  check("D: Profiles sub-tabs: Import, Export, Recycle Bin", table.concat(s, ",") == "import=Import,export=Export,bin=Recycle Bin" and p.childGroups == "tab", table.concat(s, ","))
  local ticks = {}
  for k, v in pairs(p.args.export.args) do if k:find("^inc_") and v.type == "toggle" then ticks[#ticks + 1] = { o = v.order, n = v.name } end end
  table.sort(ticks, function(a, b) return a.o < b.o end)
  local tn = {}
  for _, t in ipairs(ticks) do tn[#tn + 1] = t.n end
  check("D: Export: one tick box per component", table.concat(tn, ", ") == "Rules and groups, Themes, Settings, QoL, Bonus Features, Blizzard Reskin", table.concat(tn, ", "))
  check("D: the Recycle Bin page is there (its Empty button)", p.args.bin and p.args.bin.args and (p.args.bin.args.empty ~= nil or p.args.bin.args.summary ~= nil))
  local picked = {}
  local realSelect = ACD.SelectGroup
  ACD.SelectGroup = function(self, app, ...) picked[#picked + 1] = table.concat({ ... }, ">"); return true end
  ns.UI.Settings(); local a = picked[#picked]
  ns.UI.RecycleBin(); local b = picked[#picked]
  ns.UI.Export(); local c = picked[#picked]
  ACD.SelectGroup = realSelect
  check("D: Settings opens the Settings tab", a == "set", a)
  check("D: the Recycle Bin opens Profiles > Recycle Bin", b == "profiles>bin", b)
  check("D: Export opens Profiles > Export", c == "profiles>export", c)
end)

section("E: the profile codec", function()
  local P = ns.Profile
  check("E: the profile component list exists", P ~= nil and #P.COMPONENTS == 6)
  local DB = CueRulesDB
  DB.chat2 = DB.chat2 or {}
  DB.chat2.fadeMarker = 7
  DB.chat2.whisperSounds = { list = { { who = "Friendname-Realm" } }, fav = { enabled = true } }
  DB.calculator = { enabled = true, history = { "1+1 = 2" }, x = 5 }
  DB.ui = DB.ui or {}
  DB.ui.selStyle = "bar"; DB.ui.hybridMigrated = true
  DB.dataPanels = DB.dataPanels or {}; DB.dataPanels.markerA = "a"
  local txt, err = ns.Share.Encode("profile", P.Snapshot({ settings = true, reskin = true, bonus = true }, "mine"))
  check("E: a profile encodes", type(txt) == "string" and txt:find("^XUIPROFILE1:") ~= nil, err)
  local data, def = ns.Share.Read(txt)
  check("E: ...and reads back as a profile", data and def and def.kind == "profile", def)
  local held = {}
  for _, c in ipairs(P.Held(data)) do held[#held + 1] = c.key end
  check("E: it holds exactly the ticked components", table.concat(held, ",") == "settings,bonus,reskin", table.concat(held, ","))
  local w = data.parts.reskin.chat2.whisperSounds
  check("E: other players' names never leave (whisper-sound senders)", w and w.list == nil and w.fav and w.fav.enabled == true, w and tostring(w.list))
  check("E: the calculator's history and position never leave", data.parts.bonus.calculator.history == nil and data.parts.bonus.calculator.x == nil and data.parts.bonus.calculator.enabled == true)
  check("E: one-time upgrade flags never leave", data.parts.settings.ui.hybridMigrated == nil and data.parts.settings.ui.selStyle == "bar")
  -- import on a changed setup: only the ticked components land; settings merge
  DB.chat2.fadeMarker = 1; DB.chat2.onlyMine = "keep"
  DB.ui.selStyle = "text"
  DB.dataPanels.markerA = "changed"
  local res = def.Apply(data, { inc = { reskin = true, settings = true }, rules = "add" })
  check("E: the ticked components are applied", DB.chat2.fadeMarker == 7 and DB.ui.selStyle == "bar", tostring(DB.chat2.fadeMarker) .. " " .. tostring(DB.ui.selStyle))
  check("E: an unticked component is left alone (Bonus Features)", DB.dataPanels.markerA == "changed", DB.dataPanels.markerA)
  check("E: settings are merged: a value the profile lacks stays", DB.chat2.onlyMine == "keep")
  check("E: ...and the import says what it applied and asks for a reload", res and res.reload == true and #res.done == 2, res and #(res.done or {}))
  -- rules alone: the rules string
  local built = ns.BuildOptionsTable()
  local st = ns.OptionsApi.ProfileState()
  for k in pairs(st.profInc) do st.profInc[k] = (k == "rules") end
  built.args.profiles.args.export.args.gen.func()
  local box = built.args.profiles.args.export.args.exportBox.get()
  check("E: Rules and groups alone export as a rules string (XUI1, older versions read it)", tostring(box):find("^XUI1:") ~= nil, tostring(box):sub(1, 20))
  for k in pairs(st.profInc) do st.profInc[k] = true end
  built.args.profiles.args.export.args.gen.func()
  box = built.args.profiles.args.export.args.exportBox.get()
  check("E: with more parts ticked it is a profile string", tostring(box):find("^XUIPROFILE1:") ~= nil, tostring(box):sub(1, 20))
  -- Import tab: pasted profile lists its parts, each ticked
  built.args.profiles.args.import.args.importBox.set({}, txt)
  built = ns.BuildOptionsTable()
  local ia = built.args.profiles.args.import.args
  local function vis(o) local h = o.hidden; if type(h) == "function" then h = h() end; return not h end
  check("E: Import shows a tick box for each held component", vis(ia.imp_settings) and vis(ia.imp_bonus) and vis(ia.imp_reskin) and not vis(ia.imp_rules) and not vis(ia.imp_qol))
  check("E: ...each ticked to start", ia.imp_settings.get() and ia.imp_reskin.get())
  -- a doctored profile is cleaned
  local bad = { v = 1, parts = { evil = { x = 1 }, settings = { ui = "notatable", minimap = { hide = true }, errorLog = { 1 } } } }
  local clean = P.Check(bad)
  check("E: a pasted profile keeps only known components and their own tables", clean.parts.evil == nil and clean.parts.settings.ui == nil
    and clean.parts.settings.minimap and clean.parts.settings.errorLog == nil)
end)
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
