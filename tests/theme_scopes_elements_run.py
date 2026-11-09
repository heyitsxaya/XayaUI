#!/usr/bin/env python3
"""Debug batch W9b, issue #472 (XayaUI 0.6.82, Options 0.6.104): theme scopes per element.
Triage: docs/process/audits/debug-triage-2026-11-08.md row #472; design docs/plans/PLATFORM-SPLIT-2026-11-07.md section 6.6.
Her words (Xaya 2026-11-07): "I think we also need to enable individual element themeing and overrides somewhere -- let's make that
part of our rebuild as we configure proper plumbing. Perhaps Blizzard Reskin has a theme selector that compiles all elements that are
overhauled and each has a theme override? The XayaUI Settings Theme can be the initial fallback but users can customize at different
levels of granularity?" The page (plan 6.6): "a table of every restyled element with the columns Element | Theme (Inherit / any
built-in or saved theme) | Overrides (count, Edit) | Comes from (Global / Blizzard Reskin / this element) | Reset. Each element's own
page also gets one 'Theme' row linking to it." Q8 "Both", Q9 "Both". Element level only (module level waits for B5 / Q7).
Main holds XayaUI, XayaUI_Options and XayaUI_Rules only. The restyled elements of the modules that live on another branch (the Blizzard
Reskin pages, the Esc Menu, Chat Panel, Character Pane, Shopping List) are not on main, so on main the Platform's two scopes ("reskin",
the module level, and "settings", the settings window) are the only ones and the Theme page is not built (G). The scope plumbing (core
Theme.lua) and the Theme page (XayaUI_Options/ScopeEditor.lua) stay on main for the modules that register elements; the "elements" run
registers one stand-in element the way such a module does (T.RegisterScope with parent "reskin" and its page key, plus its own page in the
Blizzard Reskin tab through ns.RegisterSettingsPage) and reads what it draws through T.Col with its scope, the call those elements paint
with. The settings window is the real element: its frame's backdrop colours are read as drawn.
  A The elements: the stand-in and the settings window each have a scope; the Theme page lists exactly those (not the module level),
    with the columns Element | Theme | Overrides (count + Edit) | Comes from | Reset, in that order, laid out one line per row; the
    element's own page has one "Theme" row that opens its editor.
  B No override: every element draws exactly the global theme's colours.
  C An element given another theme (through its Theme cell, as the player picks it) changes only that element's drawn colours, to
    that theme's; every other element is unchanged; its row says "this element"; Reset (its row's button) puts back exactly the
    colours of B and "Global". Inherit stores nothing; a saved theme can be picked.
  D A single colour through the editor (Edit, then a palette swatch) changes only that element; the count says 1; "Reset all
    overrides" clears every element; Settings > Theme "Reset everything" leaves the elements' overrides (C15: global only).
  F (plain run) nothing is stored at all (theme.scopes absent): profiles and themes export as before (byte for byte:
    tests/profile_parts_run.py A, tests/theme_gradient_borders_run.py E).
  G (main as it is, no element registered) only the Platform's two scopes exist; no Theme page.
Negative control: on accb5c8 (before W9b) every check of A, C and D fails or the run stops at the first missing call; B and F's
"nothing stored" pass there by design. debug-log 2026-11-08 debug-w9b.
Run: python3 tests/theme_scopes_elements_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get("XUI_HARNESS") or os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L, mode)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function f3(c) return c and ("%.3f,%.3f,%.3f"):format(c[1] or -1, c[2] or -1, c[3] or -1) or "nil" end
local function same(a, b) return a and b and math.abs(a[1] - b[1]) < 0.002 and math.abs(a[2] - b[2]) < 0.002 and math.abs(a[3] - b[3]) < 0.002 end

L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
local T = ns.Theme
-- (elements run) the stand-in element, registered the way a module with a restyled element registers it (see the header)
local XT, XT_PAGE = "reskin.xuitest", "xuitestpage"
if mode == "elements" then
  T.RegisterScope({ id = XT, label = "Stand-in Element", parent = "reskin", page = XT_PAGE })
  ns.RegisterSettingsPage("reskin", XT_PAGE, function()
    return { type = "group", name = "Stand-in Element", args = { text = { type = "description", order = 1, name = "stand-in" } } }
  end)
end

if mode == "main" then
  local ids = {}
  for _, id in ipairs(T.scopeList or {}) do ids[#ids + 1] = id end
  check("G main: only the Platform's own scopes exist (reskin, settings)", #ids == 2 and T.scopes.reskin ~= nil and T.scopes.settings ~= nil, table.concat(ids, ","))
  if ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
  local SE = ns.OptionsApi and ns.OptionsApi.ScopeEditor
  check("G ...and no Theme page is built (nothing restyled)", SE ~= nil and SE.Build(nil) == nil and (ns.BuildSettingsPages("reskin", nil).rsktheme == nil))
  return R
end

if mode == "plain" then
  check("F nothing is stored: no theme.scopes", type(CueRulesDB.theme) ~= "table" or CueRulesDB.theme.scopes == nil, CueRulesDB.theme and CueRulesDB.theme.scopes)
  return R
end

-- open the settings window (the settings window is one of the elements)
if ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS")
local ACD = LibStub("AceConfigDialog-3.0")
if not (ACD.OpenFrames and ACD.OpenFrames.CueRules) then pcall(ns.ToggleUI) end; W.tick(0.05, 6)
local of = ACD.OpenFrames and ACD.OpenFrames.CueRules
local fr = of and of.frame
local function repaint() W.tick(0.1, 4); if ns.DecorateTrees then pcall(ns.DecorateTrees) end; W.tick(0.1, 2) end

-- what each element draws now (lists of colours)
local function snap()
  local s = {}
  s[XT] = { T.Col("xui-window", "bg", XT), T.Col("xui-label", "text", XT) }
  repaint()
  s["settings"] = { fr and fr._bdcolor, fr and fr._bdborder }
  return s
end
local IDS = { XT, "settings" }
-- the elements the checks below pick on (before main held only the Platform, Options and Rules: Status Bars, Minimap, Tooltips, Menus)
local E_STAT, E_MIN, E_TIP, E_MENU = XT, "settings", XT, "settings"
local function str(list) local o = {}; for i, c in ipairs(list or {}) do o[i] = f3(c) end; return table.concat(o, " | ") end
local function eq(a, b) if #a ~= #b then return false end for i = 1, #a do if not same(a[i], b[i]) then return false end end return true end
local function diffs(a, b, except)
  local out = {}
  for _, id in ipairs(IDS) do if id ~= except and not eq(a[id], b[id]) then out[#out + 1] = id .. ": " .. str(a[id]) .. " -> " .. str(b[id]) end end
  return out
end

-- A ------------------------------------------------------------------------------------------------------------------------------
local PAGES = { [XT] = XT_PAGE }
check("A the stand-in element has a scope under Blizzard Reskin with its page key", T.scopes[XT] and T.scopes[XT].parent == "reskin" and T.scopes[XT].page == XT_PAGE)
check("A the settings window has its scope", T.scopes.settings ~= nil and T.scopes.settings.label == "Settings window")
local SE = ns.OptionsApi and ns.OptionsApi.ScopeEditor
check("A Blizzard Reskin has a Theme page", SE ~= nil and ns.OptionsApi.pageTab and ns.OptionsApi.pageTab.rsktheme == "reskin", SE and ns.OptionsApi.pageTab and ns.OptionsApi.pageTab.rsktheme)
if not SE then return R end
local notified = 0
local page = SE.Build(function() notified = notified + 1 end)
local args = page.args
local function plain(v) if type(v) == "function" then v = v() end; return (tostring(v or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local heads = {}
local keys = {}
for k, v in pairs(args) do keys[#keys + 1] = k end
table.sort(keys, function(a, b) return (args[a].order or 0) < (args[b].order or 0) end)
for _, k in ipairs(keys) do if k:find("^h_") then heads[#heads + 1] = plain(args[k].name) end end
check("A the table's columns are exactly Element | Theme | Overrides | Comes from | Reset", table.concat(heads, " | ") == "Element | Theme | Overrides | Comes from | Reset", table.concat(heads, " | "))
local rowsSeen, order = {}, {}
for _, k in ipairs(keys) do local id = k:match("^el_(.+)$"); if id then rowsSeen[#rowsSeen + 1] = plain(args[k].name) end end
local want = {}
for _, id in ipairs(T.scopeList) do if id ~= "reskin" then want[#want + 1] = T.scopes[id].label end end
table.sort(want, function(a, b) return a:lower() < b:lower() end)
check("A one row per element (2: the stand-in, Settings window), not the module level", #rowsSeen == 2 and table.concat(rowsSeen, ",") == table.concat(want, ",")
  and table.concat(want, ",") == "Settings window,Stand-in Element", table.concat(rowsSeen, ","))
local K = function(id) return (id:gsub("[^%w]", "_")) end
local cellsOk = true
for _, id in ipairs(IDS) do
  local k = K(id)
  local seq = {}
  for _, key in ipairs(keys) do if key:sub(-#k - 1) == "_" .. k and not key:find("^h_") then seq[#seq + 1] = key:match("^(%a+)_") .. ":" .. args[key].type end end
  if table.concat(seq, ",") ~= "el:description,th:select,n:description,ed:execute,cf:description,rs:execute" then cellsOk = false; check("A row cells of " .. id, false, table.concat(seq, ",")) end
end
check("A each row: Element | Theme (a list) | Overrides (the count, then Edit) | Comes from | Reset", cellsOk)
local tv = SE.ThemeValues()
local miss = {}
for _, k in ipairs(T.BUILTIN_ORDER) do if not tv[k] then miss[#miss + 1] = k end end
check("A the Theme list: Inherit first, then every built-in theme", SE.ThemeSorting()[1] == "inherit" and tv.inherit == "Inherit" and tv.class and tv.default and #miss == 0, table.concat(miss, ","))
T.Save("Mine")
check("A ...and the saved themes", SE.ThemeValues()["saved:Mine"] == "Saved: Mine")
check("A a row's widths add up to the whole page (1: Skin.lua's table rows close at 1)", math.abs(SE.WIDTHS.el + SE.WIDTHS.theme + SE.WIDTHS.n + SE.WIDTHS.edit + SE.WIDTHS.from + SE.WIDTHS.reset - 1) < 1e-6)
-- The table as it is drawn (Xaya's screenshot, 2026-11-08, REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s #7: the rows ran on as one
-- wrapped stream, the header line ended with "Blizzard Windows" and the Edit / Reset buttons were cut to "E..." / "R..."). Skin.lua's
-- FlexPrepass sizes the cells, then AceGUI's Flow (Libs/AceGUI-3.0/AceGUI-3.0.lua, Flow: a control goes to a new line when its width
-- plus the line's used width passes the pane) places them. Expected: one line per table row, each starting with its Element cell.
local cellKeys = {}
for _, k in ipairs(keys) do local o = args[k]; if o.width == "relative" and type(o.arg) == "table" and o.arg.xuiCell then cellKeys[#cellKeys + 1] = k end end
local function Lines(paneW)
  local kids = {}
  for _, k in ipairs(cellKeys) do
    local o = args[k]
    local w = { width = "relative", relWidth = o.relWidth, key = k, frame = { width = 10, GetWidth = function() return 10 end },
                type = (o.type == "select" and "Dropdown") or (o.type == "execute" and "Button") or "Label" }
    w.GetUserData = function(_, u) if u == "option" then return o end end
    w.SetWidth = function(self, v) self.frame.width = v end
    kids[#kids + 1] = w
  end
  local okP, errP = pcall(ns.FlexPrepass, { width = paneW, GetWidth = function() return paneW end }, kids)
  if not okP then return nil, tostring(errP) end
  local lines, used = {}, 0
  for _, w in ipairs(kids) do
    local fw = paneW * (w.relWidth or 1)
    if #lines == 0 or used + fw > paneW then lines[#lines + 1] = {}; used = 0 end
    table.insert(lines[#lines], w.key); used = used + fw
  end
  return lines, kids
end
for _, paneW in ipairs({ 450, 600, 800 }) do
  local lines, kids = Lines(paneW)
  local bad = {}
  if not lines then bad[1] = "FlexPrepass error " .. tostring(kids) else
    if #lines ~= #rowsSeen + 1 then bad[#bad + 1] = #lines .. " lines for " .. (#rowsSeen + 1) .. " rows" end
    for i, ln in ipairs(lines) do
      local want1 = (i == 1) and "h_el" or "^el_"
      if not ln[1]:find(want1) then bad[#bad + 1] = "line " .. i .. " starts with " .. ln[1] .. " (" .. table.concat(ln, " ") .. ")"; break end
    end
    -- the Reset cell keeps its own share of the page: no row is squeezed to make room for the next row's cells
    for _, w in ipairs(kids) do
      if w.key:find("^rs_") and w.relWidth < SE.WIDTHS.reset * (paneW - 16) / paneW - 1e-6 then bad[#bad + 1] = w.key .. " squeezed to " .. string.format("%.3f", w.relWidth); break end
    end
  end
  check(("A the table at a %d px pane: one line per row, each starting with its Element cell; nothing squeezed"):format(paneW), #bad == 0, table.concat(bad, "; "))
end
-- each element's own page: one "Theme" row opening its editor
local tabs = ns.OptionsApi.ModuleTabs(nil)
local rk = tabs.reskin and tabs.reskin.args or {}
local rowBad = {}
for id, pg in pairs(PAGES) do
  local p = rk[pg]
  local row = p and p.args and p.args.xuiTheme
  if not (row and row.type == "execute" and row.name == "Theme") then rowBad[#rowBad + 1] = pg end
end
check("A every element's own page has one \"Theme\" row", #rowBad == 0, table.concat(rowBad, ","))
local opened
local rawOpen = ns.OpenSettingsPage
ns.OpenSettingsPage = function(m, k) opened = m .. ">" .. k end
local tipPg = PAGES[E_TIP]
if rk[tipPg] and rk[tipPg].args.xuiTheme then rk[tipPg].args.xuiTheme.func() end
ns.OpenSettingsPage = rawOpen
check("A the element's Theme row opens Blizzard Reskin > Theme with its editor open",
  opened == "reskin>rsktheme" and SE.editing == E_TIP, tostring(opened) .. " " .. tostring(SE.editing))
SE.editing = nil

-- B ------------------------------------------------------------------------------------------------------------------------------
local base = snap()
local G = T.GlobalCol
local expect = {
  [XT] = { G("xui-window", "bg"), G("xui-label", "text") },
  ["settings"] = { G("xui-window", "bg"), G("xui-window", "border") },
}
local bBad = {}
for id, e in pairs(expect) do if not eq(base[id], e) then bBad[#bBad + 1] = id .. ": " .. str(base[id]) .. " vs " .. str(e) end end
check("B no override: every element draws exactly the global theme's colours", #bBad == 0, table.concat(bBad, " ; "))

-- C ------------------------------------------------------------------------------------------------------------------------------
local LIGHT = T.BUILTIN.light.pal
-- the palette colour each element's first drawn colour comes from
local FIRST = {}   -- (every element here draws its window background first)
local function lightOf(id)
  local s = snap()
  local d = diffs(base, s, id)
  return s, d
end
local cBad = {}
for _, id in ipairs(IDS) do
  local k = K(id)
  args["th_" .. k].set(nil, "light")
  local s, d = lightOf(id)
  local changed = not eq(base[id], s[id])
  local first = s[id][1]
  local wantFirst = LIGHT[FIRST[id] or "windowBg"]
  local okFirst = same(first, wantFirst)
  local row = args["th_" .. k].get() == "light" and plain(args["cf_" .. k].name) == "this element" and plain(args["n_" .. k].name) == "0"
  if not (changed and okFirst and #d == 0 and row) then
    cBad[#cBad + 1] = id .. (changed and "" or " unchanged") .. (okFirst and "" or (" first " .. f3(first) .. " want " .. f3(wantFirst))) .. (#d == 0 and "" or (" others: " .. table.concat(d, " ; "))) .. (row and "" or (" row " .. tostring(args["th_" .. k].get()) .. "/" .. plain(args["cf_" .. k].name)))
  end
  args["rs_" .. k].func()
  local back = snap()
  local d2 = diffs(base, back, nil)
  local backFrom = "Global"
  if #d2 > 0 or plain(args["cf_" .. k].name) ~= backFrom or args["th_" .. k].get() ~= "inherit" then cBad[#cBad + 1] = id .. " after Reset: " .. table.concat(d2, " ; ") .. " " .. plain(args["cf_" .. k].name) end
end
check("C each element given Light mode in its Theme cell: only its own colours change, to Light's; its row says Light / this element; Reset puts back exactly today's colours and Global", #cBad == 0, table.concat(cBad, " || "))
args["th_" .. K(E_MENU)].set(nil, "light"); args["th_" .. K(E_MENU)].set(nil, "inherit")
check("C Inherit stores nothing", CueRulesDB.theme.scopes == nil or CueRulesDB.theme.scopes[E_MENU] == nil)
-- a saved theme picked for one element
args["th_" .. K(E_TIP)].set(nil, "saved:Mine")
check("C a saved theme can be picked for an element (stored by name)", T.ScopeData(E_TIP) and T.ScopeData(E_TIP).theme == "Mine" and args["th_" .. K(E_TIP)].get() == "saved:Mine")
args["rs_" .. K(E_TIP)].func()

-- D ------------------------------------------------------------------------------------------------------------------------------
SE.Open(E_STAT, nil)
local ed = args.editor
check("D Edit opens the element's editor (its name, a Theme list, the palette)", not ed.hidden() and plain(ed.name) == T.scopes[E_STAT].label and ed.args.theme and ed.args.tok_windowBg ~= nil)
ed.args.tok_windowBg.set(nil, 0.5, 0.1, 0.1, 1)
local s = snap()
local d = diffs(base, s, E_STAT)
check("D one colour set in the editor: only that element changes, to that colour", same(s[E_STAT][1], { 0.5, 0.1, 0.1 }) and #d == 0, f3(s[E_STAT][1]) .. " " .. table.concat(d, " ; "))
check("D ...its row counts 1 override and says this element", plain(args["n_" .. K(E_STAT)].name) == "1" and plain(args["cf_" .. K(E_STAT)].name) == "this element")
local r1, g1 = ed.args.tok_windowBg.get()
check("D the editor's swatch shows the element's colour", math.abs(r1 - 0.5) < 0.002 and math.abs(g1 - 0.1) < 0.002)
args["th_" .. K(E_MIN)].set(nil, "colorblind")
T.ResetAll()
check("D Settings > Theme \"Reset everything\" leaves the elements' overrides (C15: global only)", T.ScopeData(E_STAT) ~= nil and T.ScopeData(E_MIN) ~= nil)
check("D \"Reset all overrides\" is offered and asks first", not args.resetAll.disabled() and type(args.resetAll.confirm) == "function")
args.resetAll.func()
local s2 = snap()
check("D \"Reset all overrides\" clears every element: nothing stored, everything draws as before", CueRulesDB.theme.scopes == nil and #diffs(base, s2, nil) == 0 and SE.editing == nil, table.concat(diffs(base, s2, nil), " ; "))
check("D ...and is greyed with nothing to reset", args.resetAll.disabled())

return R
end
'''


def world_and_loader(enabled_filter, saved):
    folders = H.find_addons()
    enabled = [n for n in folders if enabled_filter(n)]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": saved}))
    return L, world, loader


def run(mode, enabled_filter, saved):
    L, world, loader = world_and_loader(enabled_filter, saved)
    fn = L.eval("function(src, W, Ld, mode) return loadstring(src)()(W, Ld, mode) end")
    res = fn(LUA, world, loader, mode)
    bad = 0
    out = []
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        out.append(("PASS " if ok else "FAIL ") + "[%s] " % mode + str(name)[:1500])
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    return out, bad, errs, len(res)


def main():
    total = bad = 0
    allerrs = []
    runs = [
        ("elements", lambda n: True, {}),
        ("plain", lambda n: True, {}),
        ("main", lambda n: True, {}),
    ]
    for mode, flt, saved in runs:
        out, b, errs, n = run(mode, flt, saved)
        for line in out:
            print(line)
        for e in errs:
            print("ERROR in the game stand-in [%s]:" % mode, str(e)[:600])
        total += n
        bad += b
        allerrs += errs
    print("%d checks, %d failed, %d Lua errors" % (total, bad, len(allerrs)))
    return 1 if bad or allerrs else 0


if __name__ == "__main__":
    sys.exit(main())
