#!/usr/bin/env python3
"""The settings window's new top level (Options 0.6.72; REQUEST-LOG UI-23 to UI-27, Xaya 2026-11-06, her words:
  "I believe these almost exclusively belong to rules so they should be put under the rules tab and the Rules / QOL / Bonus Features /
  Reskin / Settings should be at the top level now instad"; tab label "Blizzard Reskin"; "Cog goes"; New Rule: "Rules tab's top row";
  Recycle Bin: "put into profiles instead as its own subtab"; the tab is "Profiles", "expanded as a category bucket to include all
  user-created customizations, settings, etc", "individual components can be selected to toggle").
Loads the real addons in the stand-in game, opens the window and checks what the player sees and gets:
  A the top tabs read exactly Rules | QoL | Bonus Features | Blizzard Reskin | Profiles | Settings, in that order, with the feature addons
    installed (a feature tab is built from the pages its addon registers); on main, which holds no feature addon (XayaUI, XayaUI_Options and
    XayaUI_Rules only), exactly Rules | Profiles | Settings. No Recycle Bin and no Import / Export top tab; Settings shows beside the
    others (nothing hides when it is picked); the top tabs share the row evenly.
  B no toolbar: the window has no xuiToolbar shown, and the content starts under the title strip (-34, not -62).
  C "+ New Rule" is a flat button at the left end of the Rules row, before Smart Categories; the tabs follow it, Auto-Generate Rules
    stays at the far right; a click starts a new rule (the type picker); the button hides when that container shows another row.
  D Profiles has the sub-tabs Import, Export, Recycle Bin; Export has one tick box per registered component (the Platform's Themes,
    Settings and Blizzard Reskin, XayaUI Rules' Rules and groups, and QoL / Bonus Features / Nameplates where those addons are); Recycle
    Bin is the old bin page.
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

# QA-branch modules: main keeps only XayaUI (core), XayaUI_Options and XayaUI_Rules (the rule editor is part of it, Rules 0.7.0); Chat,
# Reskin, Nameplates, QoL, Bonus Features, Dev Assist and Media are on the QA branch only. A check about one of them runs when its folder is
# here; absent, it is printed as SKIP (never silently), or the check asserts what the window shows without it.
ABSENT = [a for a in ("XayaUI_Chat", "XayaUI_Reskin", "XayaUI_Nameplates", "XayaUI_QoL", "XayaUI_Bonus")
          if not os.path.isdir(os.path.join(H.ROOT, a))]

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function skip(addon, name) R[#R + 1] = { "SKIP (QA-branch module absent: " .. addon .. ") " .. name, true } end
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
  -- (with QoL and Bonus Features installed: the six tabs; main held no feature addon, so no feature tab was built. Bonus 0.6.45, A24
  -- #10: main holds XayaUI Bonus Features with the Stat Calculator only, so its tab is built: Rules | Bonus Features | Profiles | Settings)
  local want = XUI_HAS_QOL and "Rules | QoL | Bonus Features | Blizzard Reskin | Profiles | Settings"
    or (XUI_HAS_BONUS_TAB and "Rules | Bonus Features | Profiles | Settings" or "Rules | Profiles | Settings")
  check("A: the top tabs read " .. want, got == want, got)
  check("A: no Recycle Bin top tab", built.args.recyclebin == nil)
  check("A: the Profiles tab is named Profiles (not Import / Export)", built.args.profiles and built.args.profiles.name == "Profiles", built.args.profiles and built.args.profiles.name)
end)

pcall(ns.ToggleUI); W.tick(0.05, 6)
check("the window opened", root() ~= nil)

section("A/B: the window", function()
  ACD:SelectGroup("CueRules", "set", "ui"); W.tick(0.05, 6)
  local top = rowWith("set")
  check("A: Settings picked: the top row still shows Rules" .. (XUI_HAS_QOL and ", QoL" or "") .. ", Profiles beside Settings", top ~= nil and (function()
    local seen = {}
    for _, t in ipairs(shownTabs(top)) do seen[t.value] = true end
    return seen.cooldowns and (seen.qol or not XUI_HAS_QOL) and seen.profiles and seen.set
  end)(), top and #shownTabs(top))
  if top then
    local shown = shownTabs(top)
    local fw = top.frame.width or top.frame:GetWidth()
    local each, bad = fw / #shown, {}
    for i, t in ipairs(shown) do
      local _, rel, _, x = t:GetPoint(1)
      if math.abs(t:GetWidth() - each) > 0.5 or math.abs((x or -1) - (i - 1) * each) > 0.5 or rel ~= top.frame then bad[#bad + 1] = tostring(t.value) end
    end
    local nTop = XUI_HAS_QOL and 6 or (XUI_HAS_BONUS_TAB and 4 or 3)
    check("A: the " .. nTop .. " top tabs share the row evenly, edge to edge", #shown == nTop and #bad == 0, #shown .. " " .. table.concat(bad, ","))
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
  -- (Options 0.6.80: parts are registered by their modules; QoL, Bonus Features and Nameplates add their own where they are, plan 6.1)
  local wantTicks = "Rules and groups, Themes, Settings" .. (XUI_HAS_QOL and ", QoL" or "") .. ((XUI_HAS_BONUS or XUI_BONUS_PART) and ", Bonus Features" or "")
    .. ", Blizzard Reskin" .. (XUI_HAS_NAMEPLATES and ", Nameplates" or "")
  check("D: Export: one tick box per component (" .. wantTicks .. ")", table.concat(tn, ", ") == wantTicks, table.concat(tn, ", "))
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
  -- (the Platform's Themes, Settings and Blizzard Reskin, and XayaUI Rules' Rules and groups: four; QoL's, Bonus Features' and Nameplates'
  -- own parts exist only where their addons are)
  local nParts = 4 + (XUI_HAS_QOL and 1 or 0) + ((XUI_HAS_BONUS or XUI_BONUS_PART) and 1 or 0) + (XUI_HAS_NAMEPLATES and 1 or 0)
  check("E: the profile component list exists (" .. nParts .. " parts: one per registered part; Options 0.6.80)", P ~= nil and #P.COMPONENTS == nParts, P and #P.COMPONENTS)
  -- the third component ticked besides Settings and Blizzard Reskin: Bonus Features where XayaUI_Bonus is, else the Platform's Themes
  local THIRD = XUI_HAS_BONUS and "bonus" or "themes"
  local DB = ns.SettingsRoutedForTests()   -- (P5) each key where its module reads it now (its own store or CueRulesDB)
  if XUI_HAS_CHAT then   -- (Chat's keys: written only where XayaUI_Chat is)
  DB.chat2 = DB.chat2 or {}
  DB.chat2.fadeMarker = 7
  DB.chat2.whisperSounds = { list = { { who = "Friendname-Realm" } }, fav = { enabled = true } }
  end
  if XUI_HAS_BONUS then   -- (Bonus Features' keys: written only where XayaUI_Bonus is)
  DB.calculator = { enabled = true, history = { "1+1 = 2" }, x = 5 }
  DB.dataPanels = DB.dataPanels or {}; DB.dataPanels.markerA = "a"
  else DB.theme.restructureMarker = "a" end
  DB.ui = DB.ui or {}
  DB.ui.selStyle = "bar"; DB.ui.hybridMigrated = true
  local txt, err = ns.Share.Encode("profile", P.Snapshot({ settings = true, reskin = true, [THIRD] = true }, "mine"))
  check("E: a profile encodes", type(txt) == "string" and txt:find("^XUIPROFILE1:") ~= nil, err)
  local data, def = ns.Share.Read(txt)
  check("E: ...and reads back as a profile", data and def and def.kind == "profile", def)
  local held = {}
  for _, c in ipairs(P.Held(data)) do held[#held + 1] = c.key end
  check("E: it holds exactly the ticked components", table.concat(held, ",") == (XUI_HAS_BONUS and "settings,bonus,reskin" or "themes,settings,reskin"), table.concat(held, ","))
  if XUI_HAS_CHAT then
  local w = data.parts.reskin.chat2.whisperSounds
  check("E: other players' names never leave (whisper-sound senders)", w and w.list == nil and w.fav and w.fav.enabled == true, w and tostring(w.list))
  else skip("XayaUI_Chat", "E: other players' names never leave (whisper-sound senders)") end
  if XUI_HAS_BONUS then
  check("E: the calculator's history and position never leave", data.parts.bonus.calculator.history == nil and data.parts.bonus.calculator.x == nil and data.parts.bonus.calculator.enabled == true)
  else skip("XayaUI_Bonus", "E: the calculator's history and position never leave") end
  check("E: one-time upgrade flags never leave", data.parts.settings.ui.hybridMigrated == nil and data.parts.settings.ui.selStyle == "bar")
  -- import on a changed setup: only the ticked components land; settings merge
  if XUI_HAS_CHAT then DB.chat2.fadeMarker = 1; DB.chat2.onlyMine = "keep" end
  DB.ui.selStyle = "text"
  if XUI_HAS_BONUS then DB.dataPanels.markerA = "changed" else DB.theme.restructureMarker = "changed" end
  local res = def.Apply(data, { inc = { reskin = true, settings = true }, rules = "add" })
  check("E: the ticked components are applied", (not XUI_HAS_CHAT or DB.chat2.fadeMarker == 7) and DB.ui.selStyle == "bar", (XUI_HAS_CHAT and tostring(DB.chat2.fadeMarker) or "-") .. " " .. tostring(DB.ui.selStyle))   -- (Chat's half only where XayaUI_Chat is)
  if XUI_HAS_BONUS then check("E: an unticked component is left alone (Bonus Features)", DB.dataPanels.markerA == "changed", DB.dataPanels.markerA)
  else check("E: an unticked component is left alone (Themes)", DB.theme.restructureMarker == "changed", DB.theme.restructureMarker); DB.theme.restructureMarker = nil end
  if XUI_HAS_CHAT then check("E: settings are merged: a value the profile lacks stays", DB.chat2.onlyMine == "keep")
  else skip("XayaUI_Chat", "E: settings are merged: a value the profile lacks stays") end
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
  check("E: Import shows a tick box for each held component", vis(ia.imp_settings) and vis(ia["imp_" .. THIRD]) and vis(ia.imp_reskin) and not vis(ia.imp_rules)
    and (ia.imp_qol == nil or not vis(ia.imp_qol)))   -- (no QoL tick box at all where XayaUI_QoL is not: its part is not registered)
  check("E: ...each ticked to start", ia.imp_settings.get() and ia.imp_reskin.get() and ia["imp_" .. THIRD].get())
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
    has = lambda a: str(a not in ABSENT).lower()
    # (Bonus 0.6.45) XUI_HAS_BONUS: XayaUI Bonus Features with its profile part (dataPanels, tooltips, calculator: XayaUI_Bonus/
    # ProfilePart.lua, qa-installer-branch). On main XayaUI_Bonus holds only the Stat Calculator and registers no profile part, so the
    # profile checks run as without it; XUI_HAS_BONUS_TAB: the folder is here, so its top tab is built.
    # (Bonus 0.6.46, A24 #13) main's XayaUI_Bonus registers its own part again, Bonus Features = the Stat Calculator's settings
    # (XayaUI_Bonus/ProfilePart.lua, db = { "characterToolkit" }): XUI_BONUS_PART says a Bonus Features tick box is under Export;
    # XUI_HAS_BONUS stays the QA part with the data panels / calculator keys these checks write.
    pp = os.path.join(H.ROOT, "XayaUI_Bonus", "ProfilePart.lua")
    pp_src = open(pp, encoding="utf-8").read() if os.path.isfile(pp) else ""
    bonus_part = str('"dataPanels"' in pp_src).lower()
    L.execute("XUI_HAS_CHAT = %s; XUI_HAS_NAMEPLATES = %s; XUI_HAS_QOL = %s; XUI_HAS_BONUS = %s; XUI_HAS_BONUS_TAB = %s; XUI_BONUS_PART = %s"
              % (has("XayaUI_Chat"), has("XayaUI_Nameplates"), has("XayaUI_QoL"), bonus_part, has("XayaUI_Bonus"),
                 str(bool(pp_src) and "XayaUI_Bonus" not in ABSENT).lower()))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad, nchecks = 0, 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        if str(name).startswith("SKIP ("):
            print(name)
            continue
        nchecks += 1
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (nchecks, bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
