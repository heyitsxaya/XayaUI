#!/usr/bin/env python3
"""Left-pane feature rows and what their tick boxes switch, and the world map report (QoL 0.7.24, Bonus 0.6.14, core 0.6.49).
Xaya, her words (docs/process/REQUEST-LOG.md):
  #45 "yes, give an enable / disable "Enhanced Tooltips" as a feature"
  #46 "Assume yes for now" (the Character Toolkit's "Tooltip lines" get their own row and tick box)
  #47 "No. It should only enable or disable notepad functionality in its entirety" (the Notepad row's tick box)
  #30 "map eclipses full screen" [the world map full screen]; 2026-11-06: it happens "only with XayaUI on". The cause was not found
      offline (debug log of QoL 0.7.24): what is built is the /xui debug map report, checked here.
  V14 (her words): "anything that is disabled in the addon through a tick box should NEVER LOAD or contribute to performance cost /
      demand in any way".
Part 1 loads the real addons XayaUI, XayaUI_Media, XayaUI_Bonus and XayaUI_Options in the whole-addon stand-in (tests/harness) and
meters, as tests/options_bonus_off_costs_nothing_run.py does, which addon file made a frame, registered an event or placed a tooltip
post-call. Part 2 loads core's Modules.lua with XayaUI_QoL in the character window stand-in (tests/char_toolkit_world.lua,
tests/char_pane_geometry.lua through tests/char_pane_overlays_run.py's prelude).
Every check fails on the code before this change (the bundle at 1d7bbe2), except those labelled "(works)" (the feature works when on)
and "(as before)" (a fact that was already true), which pass on both: see the debug log.
Run: python3 tests/feature_rows_map_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
sys.path.insert(0, os.path.join(HERE, "harness"))
sys.path.insert(0, HERE)
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L, MODE)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { "[" .. MODE .. "] " .. name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function owner()
  for lv = 3, 40 do
    local info = debug.getinfo(lv, "S")
    if not info then break end
    local f = (info.source or ""):match("Interface/AddOns/(XayaUI[%w_]*/[%w_/]+%.lua)")
    if f then return f end
  end
  return "?"
end
local rawCreate = CreateFrame
CreateFrame = function(...) local f = rawCreate(...); rawset(f, "_owner", owner()); return f end
local calls = {}
local function meter(t, k, name)
  local raw = t[k]
  t[k] = function(...) local o = owner(); calls[name] = calls[name] or {}; calls[name][o] = (calls[name][o] or 0) + 1; if raw then return raw(...) end end
end
local function ncalls(name, file) return (calls[name] and calls[name][file]) or 0 end
meter(C_ChatInfo, "RegisterAddonMessagePrefix", "RegisterPrefix")
local TT_, TTUI, NP, NS = "XayaUI_Bonus/Tooltips.lua", "XayaUI_Bonus/TooltipsUI.lua", "XayaUI_Bonus/Notepad.lua", "XayaUI_Bonus/NotepadShare.lua"
local function owned(file) local l = {}; for _, o in ipairs(W.objects) do if rawget(o, "_owner") == file then l[#l + 1] = o end end; return l end
local function events(file)
  local set, list = {}, {}
  for _, o in ipairs(owned(file)) do for e in pairs(o._events) do if not set[e] then set[e] = true; list[#list + 1] = e end end end
  table.sort(list)
  return #list, table.concat(list, ","), set
end
local function onupdates(file) local n = 0; for _, o in ipairs(owned(file)) do if o._scripts.OnUpdate then n = n + 1 end end; return n end
local function cost(file) local ne, le = events(file); return ("%d frames, %d events (%s), %d OnUpdate"):format(#owned(file), ne, le, onupdates(file)) end
local function nothing(file) return #owned(file) == 0 and events(file) == 0 and onupdates(file) == 0 end
local function posts() return #(W.tooltipPostCalls or {}) end
local tipLines = {}
rawset(GameTooltip, "AddDoubleLine", function(self, a, b) tipLines[#tipLines + 1] = tostring(a) .. " " .. tostring(b) end)
local function hoverSpell(id)
  tipLines = {}
  for _, p in ipairs(W.tooltipPostCalls or {}) do if p[1] == Enum.TooltipDataType.Spell then p[2](GameTooltip, { id = id }) end end
  return table.concat(tipLines, " / ")
end
local function chatAddon(msg) W.fire("CHAT_MSG_ADDON", "XUINOTE", msg, "PARTY", "Friend-Realm", "", 0, 0, "", 0) end
local function offer() local o = rawget(_G, "XayaUINoteOffer"); return o ~= nil and o:IsShown() end

L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
check("(sanity) core and Bonus loaded", ns ~= nil and ns.TT ~= nil and ns.BuildNotepadTab ~= nil)
if not (ns and ns.TT) then return R end
local idCalls = 0
local rawOnID = ns.TT.OnIDData
ns.TT.OnIDData = function(...) idCalls = idCalls + 1; return rawOnID(...) end
local noop = function() end
local function ttPage() return ns.BuildTooltipsTab(noop) end
local function npPage() return ns.BuildNotepadTab(noop) end
local function launcher(key) for _, e in ipairs(ns.Launchers()) do if e[1] == key then return e end end end
local function available(key) local e = launcher(key); return e ~= nil and (type(e.available) ~= "function" or e.available() == true) end

if MODE == "off" then
  -- #45 / #47 saved off, with every part under them saved on: nothing of them exists or runs (V14)
  local tp, np = ttPage(), npPage()
  check("#45 the Tooltips page is the feature \"Enhanced Tooltips\": its row's tick box (xuiSwitch) is named exactly so and shows the saved off",
    tp.name == "Enhanced Tooltips" and tp.xuiSwitch and tp.xuiSwitch.name == "Enhanced Tooltips" and tp.xuiSwitch.get({}) == false, tp.name)
  check("(as before) #45 ...the four section switches stay on its page (IDs, Item level, Enemy forces, Formulas), each still on as saved",
    tp.args.ids.args.enabled and tp.args.ilvl.args.enabled and tp.args.forces.args.enabled and tp.args.formulas.args.enabled
    and tp.args.ids.args.enabled.get({}) == true and tp.args.formulas.args.enabled.get({}) == true)
  check("#45 Enhanced Tooltips saved off (its four sections on): no tooltip post-call is installed", posts() == 0, posts())
  check("#45 ...Tooltips.lua and TooltipsUI.lua made no frame and registered no event", nothing(TT_) and nothing(TTUI), cost(TT_) .. " | " .. cost(TTUI))
  check("#45 ...hovering a spell runs no XayaUI code and adds no line", hoverSpell(133) == "" and idCalls == 0, idCalls)
  check("#47 the Notepad row's tick box is the whole feature (named \"Notepad\"), saved off; \"Show Notepad\" is on its page, greyed out while the Notepad is off",
    np.xuiSwitch and np.xuiSwitch.name == "Notepad" and np.xuiSwitch.get({}) == false and np.args.show and np.args.show.name == "Show Notepad"
    and np.args.show.type == "toggle" and np.args.show.disabled() == true, np.xuiSwitch and np.xuiSwitch.name)
  check("#47 Notepad saved off (Show Notepad and Accept shared notes saved on): no box, nothing of Notepad.lua exists",
    rawget(_G, "XayaUINotepad") == nil and nothing(NP), cost(NP))
  check("#47 ...its sharing included: NotepadShare.lua made nothing, listens to nothing, registered no prefix",
    nothing(NS) and ncalls("RegisterPrefix", NS) == 0, cost(NS))
  chatAddon("D|abcd|1|1|A whole note in one part.")
  check("#47 ...a shared note is not offered", not offer())
  ns._capture = {}
  pcall(SlashCmdList.XAYAUI, "notes")
  local said = table.concat(ns._capture, " | "); ns._capture = nil
  check("#47 ...\"/xui notes\" builds nothing and says the Notepad is off", rawget(_G, "XayaUINotepad") == nil and nothing(NP) and said:find("Notepad is off", 1, true) ~= nil, said)
  pcall(ns.NotepadShare_OpenIO, "all"); pcall(ns.Notepad_ToggleRestore)
  check("#47 ...export / import and the Restore list open nothing", rawget(_G, "XayaUINoteIO") == nil and rawget(_G, "XayaUINotepadRestore") == nil)
  check("#47 ...the minimap list has no Notes row", launcher("notes") ~= nil and not available("notes"))
  -- switched on through their rows' tick boxes
  do local sw = ttPage().xuiSwitch; if sw then sw.set({}, true) end end; W.tick(0.05, 2)
  check("(works) #45 Enhanced Tooltips ticked: the post-calls are installed and a spell shows its ID",
    posts() == 11 and hoverSpell(133):find("Spell ID: 133", 1, true) ~= nil, posts() .. " | " .. hoverSpell(133))
  do local sw = npPage().xuiSwitch; if sw then sw.set({}, true) end end; W.tick(0.05, 2)
  local box = rawget(_G, "XayaUINotepad")
  local n1, l1 = events(NP)
  local _, ls, sets = events(NS)
  check("(works) #47 Notepad ticked: the box (saved shown) is built and shown, its events registered", box ~= nil and box:IsShown() and n1 == 3, l1)
  check("(works) #47 ...shared notes are listened to again (Accept is on)", sets.CHAT_MSG_ADDON == true and available("notes"), ls)
  chatAddon("D|efgh|1|1|Another whole note.")
  check("(works) #47 ...and a shared note is offered", offer())
  local of = rawget(_G, "XayaUINoteOffer"); if of then of:Hide() end
  local npWasOn = ns.notepadDB.enabled
  -- and off again: they stop at once
  do local sw = ttPage().xuiSwitch; if sw then sw.set({}, false) end end; W.tick(0.05, 2)
  idCalls = 0
  check("#45 Enhanced Tooltips unticked: hovering a spell runs no XayaUI code (the post-calls return at once) and adds no line; every event let go",
    hoverSpell(133) == "" and idCalls == 0 and events(TT_) == 0, idCalls .. " | " .. cost(TT_))
  do local sw = npPage().xuiSwitch; if sw then sw.set({}, false) end end; W.tick(0.05, 2)
  local _, ls2, sets2 = events(NS)
  check("#47 Notepad unticked: the feature is off (it was on), the box is hidden and its events let go", npWasOn == true and ns.notepadDB.enabled == false and box and not box:IsShown() and events(NP) == 0, cost(NP))
  check("#47 ...addon messages are let go and nothing is offered", not sets2.CHAT_MSG_ADDON and (function() chatAddon("D|ijkl|1|1|Third.") return not offer() end)(), ls2)
  check("(as before) #47 ...its notes are kept", type(ns.notepadDB.notes) == "table")
elseif MODE == "defaults" then
  local tp, np = ttPage(), npPage()
  check("#45 a fresh install: Enhanced Tooltips is ticked (on, as the four sections were on by default) and works", tp.xuiSwitch and tp.xuiSwitch.get({}) == true
    and posts() == 11 and hoverSpell(133):find("Spell ID: 133", 1, true) ~= nil, posts())
  check("#47 a fresh install: the Notepad is ticked (on, as it always was); its box is not built until shown; Notes is in the minimap list",
    np.xuiSwitch and np.xuiSwitch.get({}) == true and rawget(_G, "XayaUINotepad") == nil and available("notes") and np.args.show ~= nil and np.args.show.disabled() == false)
  -- #30 the world map report (/xui debug map)
  local m = CreateFrame("Frame", "WorldMapFrame", UIParent)
  m:SetSize(1180, 690); m:Show()
  rawset(m, "IsMaximized", function() return true end)
  W.cvars.miniWorldMap, W.cvars.questLogOpen, W.cvars.useUiScale, W.cvars.uiScale = "0", "1", "1", "0.71"
  ns._capture = {}
  pcall(SlashCmdList.XAYAUI, "debug map")
  local out = ns._capture; ns._capture = nil
  local s = table.concat(out, " | ")
  check("#30 \"/xui debug map\" reports the map's display state and size", s:find("map: world map: shown true, maximized true, size 1180 x 690", 1, true) ~= nil, s)
  check("#30 ...the CVar that decides it (miniWorldMap 0 = opens full screen), questLogOpen, the UI scale CVars and the game rule",
    s:find("map: CVars: miniWorldMap 0 (1 = opens small, 0 = opens full screen), questLogOpen 1, useUiScale 1, uiScale 0.71; game rule MaximizeWorldMapDisabled", 1, true) ~= nil, s)
  check("#30 ...UIParent's size and scale, Blizzard's panel slots", s:find("map: UIParent: shown true, size ", 1, true) ~= nil and s:find("map: Blizzard's panel slots: fullscreen", 1, true) ~= nil, s)
  check("#30 ...and which XayaUI calls into Blizzard's panel layout ran since login (none here: no Character Reskin loaded)",
    s:find("map: XayaUI calls into Blizzard's panel layout since login: none", 1, true) ~= nil, s)
  -- (core 0.6.50 merged in: plain /xui debug lists the diagnostic commands, map among them; core's loader report is /xui debug loader)
  check("#30 ...plain /xui debug lists /xui debug map and does not run the report", (function() ns._capture = {}; pcall(SlashCmdList.XAYAUI, "debug"); local t = table.concat(ns._capture, " | "); ns._capture = nil
    return t:find("/xui debug map", 1, true) ~= nil and not t:find("map: world map:", 1, true) end)())
  check("#30 ...core's own loader report is /xui debug loader, without the map report", (function() ns._capture = {}; pcall(SlashCmdList.XAYAUI, "debug loader"); local t = table.concat(ns._capture, " | "); ns._capture = nil
    return t:find("debug: ToggleUI=", 1, true) ~= nil and not t:find("map:", 1, true) end)())
end
return R
end
'''


def saved_for(mode):
    if mode == "off":
        return {"XayaUI": {"CueRulesDB": {
            "tooltips": {"enabled": False},
            "notepad": {"enabled": False, "shown": True, "acceptShares": True},
            "ui": {"consoleAutoOpen": False}}}}
    return {"XayaUI": {"CueRulesDB": {"ui": {"consoleAutoOpen": False}}}}


def harness(mode):
    folders = H.find_addons()
    # (core 0.6.56, REQUEST-LOG #81: /xui debug map is XayaUI Dev Assist's, so it is loaded here)
    enabled = [n for n in folders if n in ("XayaUI", "XayaUI_Media", "XayaUI_Bonus", "XayaUI_Options", "XayaUI_DevAssist")]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    w = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), w,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": saved_for(mode)}))
    res = L.eval("function(src, W, Ld, mode) return loadstring(src)()(W, Ld, mode) end")(LUA, w, loader, mode)
    out = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errs = [str(w.errors[i])[:600] for i in range(1, len(w.errors) + 1)]
    return out, errs


# Part 2: the character window stand-in (the Character Toolkit's Tooltip lines row; the map counter on the Character Reskin's calls)
PANE = r'''
R2 = {}
local function check2(name, ok, extra) R2[#R2 + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local hooked = {}
local rawHSF = hooksecurefunc
hooksecurefunc = function(a, b, c) local k = type(a) == "table" and b or a; hooked[k] = (hooked[k] or 0) + 1; return rawHSF(a, b, c) end
ns.FireReady(); ns.SettingsDeclareStore("reskin", "XayaUI_Reskin", "XayaUIReskinDB"); ns.SettingsOpenAllForTests()   -- (P5) the module addons load after XayaUI (XayaUI Blizzard Reskin on: it keeps the look half): their settings stores open (Modules.lua section 0c)
local rc, tk = ns.CharReskin_Cfg(), ns.CharToolkit_Cfg()
-- #46: the toolkit on, its Tooltip lines saved off
local statRow = mk("Frame"); statRow.Label = mk("FS"); statRow.Label.text = "Agility:"
CharacterStatsPane = CharacterStatsPane or mk("Frame"); CharacterStatsPane.children = { statRow }
tk.enabled, tk.tooltips, tk.panel = true, false, false
CharacterFrame:Show(); PaperDollFrame:Show()
ns.CharToolkit_Apply()
local page = ns.BuildCharToolkitPage(function() end)
local tp = page.args.tipsPart
check2("#46 the Character Toolkit has a \"Tooltip lines\" row of its own with its own tick box (xuiSwitch named \"Tooltip lines\"), unticked as saved",
  tp and tp.type == "group" and tp.name == "Tooltip lines" and tp.xuiSwitch and tp.xuiSwitch.name == "Tooltip lines" and tp.xuiSwitch.get({}) == false, tp and tp.name)
check2("#46 ...Panel no longer has a Tooltips tab (the switch moved to the row); the row is listed only while the toolkit is on",
  page.args.panelPart.args.tips == nil and tp and tp.hidden() == false and (function() tk.enabled = false; local h = tp.hidden(); tk.enabled = true; return h end)() == true)
check2("#46 Tooltip lines off (V14): no hook on PaperDollFrame_UpdateStats from the toolkit, no hover hook on the stat rows",
  (hooked.PaperDollFrame_UpdateStats or 0) == 0 and (statRow.hooks.OnEnter == nil or #statRow.hooks.OnEnter == 0), tostring(hooked.PaperDollFrame_UpdateStats))
if tp and tp.xuiSwitch then tp.xuiSwitch.set({}, true) end
GameTooltip.lines = {}
local hk = statRow.hooks.OnEnter and statRow.hooks.OnEnter[1]
if hk then GameTooltip:SetOwner(statRow); hk(statRow) end
local said = table.concat(GameTooltip.lines or {}, " | ")
check2("(works) #46 its tick box on: the stat rows are hooked once and the Agility tooltip gets the toolkit's lines",
  tk.tooltips == true and hk ~= nil and #statRow.hooks.OnEnter == 1 and (hooked.PaperDollFrame_UpdateStats or 0) == 1 and said:find("XayaUI", 1, true) ~= nil, said)
if tp and tp.xuiSwitch then tp.xuiSwitch.set({}, false) end
GameTooltip.lines = {}
if hk then hk(statRow) end
check2("#46 ...off again: the hook returns at once (no line added; a /reload removes it)", tp ~= nil and hk ~= nil and tk.tooltips == false and #(GameTooltip.lines or {}) == 0, #(GameTooltip.lines or {}))
-- #30: the map report counts the Character Reskin's calls into Blizzard's panel layout
rc.enabled, rc.wide = true, true
ns.CharReskin_Apply()
CharacterFrame:UpdateSize()
local counts = ns.MapTraceCounts and ns.MapTraceCounts() or {}
local up = counts["Character Reskin: UpdateUIPanelPositions(CharacterFrame) (wider window)"]
local hookN = counts["Character Reskin: hook after CharacterFrame:UpdateSize"]
check2("#30 the map report counts the Character Reskin's UpdateUIPanelPositions(CharacterFrame) and its hook after CharacterFrame:UpdateSize",
  up and up.n >= 1 and hookN and hookN.n >= 1, tostring(up and up.n) .. " / " .. tostring(hookN and hookN.n))
local lines = DA_MAPLINES(ns)   -- (the report's lines: XayaUI Dev Assist's MapLines, core 0.6.56)
local s = table.concat(lines, " | ")
check2("#30 ...and lists them in /xui debug map (world map not loaded in this stand-in: said so)",
  s:find("world map: not loaded yet", 1, true) ~= nil and s:find("XayaUI since login: Character Reskin: UpdateUIPanelPositions(CharacterFrame) (wider window) x", 1, true) ~= nil, s)
'''


def pane():
    src = open(os.path.join(HERE, "char_pane_overlays_run.py"), encoding="utf-8").read()
    g = {"__file__": os.path.join(HERE, "char_pane_overlays_run.py"), "__name__": "feature_rows_map"}
    exec(compile(src[:src.index("TOTAL_N, TOTAL_F = 0, 0")], "char_pane_overlays_run.py (prelude)", "exec"), g)
    lua = g["lua_with"]("")
    cd = open(os.path.join(HERE, "..", "XayaUI_DevAssist", "CoreDebug.lua"), encoding="utf-8").read()
    a = cd.index("local function MapLines()"); b = cd.index("\nend\n", a) + 5
    lua.execute("DA_MAPLINES = function(ns) " + cd[a:b] + " return MapLines() end")
    lua.execute(PANE)
    res = lua.eval("R2")
    return [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]


def main():
    total, bad, errs = 0, 0, 0
    for mode in ("off", "defaults"):
        out, e = harness(mode)
        for name, ok in out:
            print(("PASS " if ok else "FAIL ") + name)
            total += 1; bad += 0 if ok else 1
        for x in e:
            print("ERROR in the game stand-in [%s]: %s" % (mode, x)); errs += 1
    try:
        for name, ok in pane():
            print(("PASS " if ok else "FAIL ") + name)
            total += 1; bad += 0 if ok else 1
    except Exception as ex:   # (the old code stops here; counted as a failed check)
        print("FAIL the character window part ran to its end: %s" % str(ex)[:300]); total += 1; bad += 1
    print("%d checks, %d failed, %d Lua errors" % (total, bad, errs))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
