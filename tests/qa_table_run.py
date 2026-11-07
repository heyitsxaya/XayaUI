#!/usr/bin/env python3
"""The walkthrough table: search box, tag chips and sortable columns in both lists of QA walkthroughs (XayaUI_DevAssist 0.7.52,
QATable.lua, used by QAReview.lua's review popup and QAWalk.lua's All walkthroughs).
Xaya 2026-11-07 (her words): "an issue search bar and issues tags here to be able to navigate more easily"; "some of these also are not
exactly human-readable"; then "the codes are fine to keep, all of this data just needs to be clearly put into tables with clear sortable
rows and columns (think excel style navigation)". Checked in the stand-in game, on what the windows draw:
 - V14: nothing of the table exists before a window opens;
 - Baseline: exactly the 10 decided walkthroughs, each registered, each marked "Baseline" in its Title cell;
 - codes vs title: only a leading [ ... ] / trailing ( ... ) group made entirely of codes leaves the title (ordinary words in brackets
   stay), and those codes plus the qa field appear, de-duplicated, in the Codes column;
 - search over each field (title, walkthrough id, qa field, a code in the title, area, step text with colour codes stripped),
   case-insensitive, empty = everything; the count;
 - chips: OR within areas and within statuses, AND across groups, AND with the search; New or changed; Clear;
 - sorting by each column, a second click reverses, ties keep the default order (area, then the list's order), the arrow;
 - the header, chips and rows sit inside the window (V11);
 - the review-search walkthrough's own checks pass on the real table (V22), including a header click changing the order;
 - nothing of the search, chips or sort is saved: CueRulesDB and XayaUIDevAssistDB are unchanged by using them, and the saved file
   written at logout has the same keys as one written without touching the table.
Every check fails on Dev Assist 0.7.51 (no QA.Table, rows without columns, titles unchanged).
Run: python3 tests/qa_table_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

COMMON = r'''
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local QA = rawget(_G, "XayaUI_DevQA")
local RV = QA and QA.Review
local ns = rawget(_G, "XayaUI_NS")
local function join(t) return table.concat(t, ",") end
local function set(t) local s = {}; for _, v in ipairs(t) do s[v] = true end; return s end
-- every key path and value of a saved table, as one sorted text (what a saved file would hold)
local function Dump(v, path, out)
  out = out or {}
  if type(v) == "table" then
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    if #keys == 0 then out[#out + 1] = path .. "={}" end
    for _, k in ipairs(keys) do Dump(v[k], path .. "." .. tostring(k), out) end
  else out[#out + 1] = path .. "=" .. tostring(v) end
  return out
end
local function Snap() return table.concat(Dump(rawget(_G, "CueRulesDB"), "CueRulesDB"), "\n") .. "\n" .. table.concat(Dump(rawget(_G, "XayaUIDevAssistDB"), "DevAssist"), "\n") end
'''

MAIN = r'''
return function(W, L)
L.startup()
''' + COMMON + r'''
check("Dev Assist has the walkthrough table", QA and QA.Table and QA.Table.Create and QA.SplitTitle)
if not (QA and QA.Table) then return R end
local TB = QA.Table
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", false, true); W.tick(0.5, 1)
check("V14: no table (no window) before one opens", QA.Window() == nil and RV.Window() == nil)
W.tick(0.5, 8)   -- (the review popup opens by itself on a first install; close it)
if RV.Window() then RV.Window():Hide() end

-- Baseline
local BASE = { "settings-toplevel", "perf-settings-click", "audit-engine", "audit-opt-bin", "audit-backup-replace", "bars-cues",
  "chat-improved-split", "reskin-switches", "audit-shopping-list", "statcalc-rows" }
local reg = 0
for _, id in ipairs(BASE) do if QA.walks[id] and QA.IsBaseline(id) then reg = reg + 1 end end
local nb = 0
for _, id in ipairs(QA.list) do if QA.IsBaseline(id) then nb = nb + 1 end end
check("Baseline: exactly the 10 decided walkthroughs, all registered", #QA.BASELINE == 10 and reg == 10 and nb == 10
  and join(QA.BASELINE) == join(BASE), reg .. " / " .. nb)

-- title codes
local function split(t) local a, c = QA.SplitTitle(t); return a .. "|" .. join(c) end
local cases = {
  { "Engine: estimate off, glow stops (D28, D56, D57)", "Engine: estimate off, glow stops|D28,D56,D57" },
  { "[B263, B264] Engine: estimate off", "Engine: estimate off|B263,B264" },
  { "[B263] Engine (J31)", "Engine|B263,J31" },
  { "Chat: move, resize and hide the chat (#210)", "Chat: move, resize and hide the chat|#210" },
  { "Settings window: tabs (H6-H9)", "Settings window: tabs|H6-H9" },
  { "Chat: settings split (UI-18 / UI-21, #246)", "Chat: settings split|UI-18,UI-21,#246" },
  { "Stat Calculator: rows (E1z195)", "Stat Calculator: rows|E1z195" },
}
local bad = {}
for _, c in ipairs(cases) do if split(c[1]) ~= c[2] then bad[#bad + 1] = split(c[1]) end end
check("a leading [codes] and a trailing (codes) group leave the title; their codes are kept", #bad == 0, join(bad))
local keep = { "2. Looks and layout (no effect on use) (1 of 7)", "A group that keeps its arrangement (Align top + Space)",
  "Chat: arrow, button strip (#229 items 1-4)", "Nameplates: target colour (XayaUI Nameplates 0.1.0)", "Review window (part 1)",
  "[Note] Something to check", "Calculator page: summary and info icon (trial)" }
bad = {}
for _, t in ipairs(keep) do if split(t) ~= t .. "|" then bad[#bad + 1] = split(t) end end
check("ordinary words in brackets or parentheses are never taken out of a title", #bad == 0, join(bad))
check("Codes: the title's codes then the qa field, each once", join(QA.Codes(QA.walks["audit-engine"])) == "D28,D56,D57,B263,B264"
  and join(QA.Codes(QA.walks["perf-settings-click"])) == "J31" and join(QA.Codes(QA.walks["chat-settings-layout"])) == "UI-18,UI-21,#246,D24,D25",
  join(QA.Codes(QA.walks["audit-engine"])) .. " / " .. join(QA.Codes(QA.walks["chat-settings-layout"])))

-- fixed data for the chips and the search: one walkthrough per field, two results, an acknowledged build then two changes
QA.Register("zz-test-idonly", { title = "Alpha walk (Q901)", area = "Zebra area", qa = "Q902", order = 999,
  steps = { { text = "|cffffd100Find|r the unicorn" } } })
local res = QA.DB().results
res["audit-engine"] = { when = 1, steps = { { r = "P" }, { r = "F" } }, fp = QA.Fingerprint(QA.walks["audit-engine"]) }
res["bars-cues"] = { when = 1, steps = { { r = "P" }, { r = "S" } }, fp = QA.Fingerprint(QA.walks["bars-cues"]) }
res["group-box"] = { when = 1, steps = { { r = "P" } }, fp = "old" }
res["group-nested"] = { when = 1, steps = { { r = "S" }, { r = "D" } }, fp = QA.Fingerprint(QA.walks["group-nested"]) }   -- (0.7.53: skipped through, clean-up Done)
RV.Acknowledge(true)
L.addons["XayaUI"].meta.Version = "9.9.99"   -- an update after the acknowledged build: new / changed count against it
QA.walks["group-page"].steps[1].text = QA.walks["group-page"].steps[1].text .. " (changed)"
QA.Register("zz-test-new", { title = "Beta walk", area = "Zebra area", order = 1000, steps = { { text = "new" } } })

-- All walkthroughs
ns.RunCommand("dev", "qa")
local Wn = QA.Window()
local t = Wn and Wn.tbl
check("/xui dev qa: the list is the table, every walkthrough a row", Wn and Wn:IsShown() and t and #t.visible == #QA.list and #t.entries == #QA.list,
  t and (#t.visible .. " of " .. #QA.list))
if not t then return R end
local hdr = {}
for i, h in ipairs(t.headers) do hdr[i] = h.text:GetText() end
check("  ...header Codes | Title | Area | Status | New | Open", join(hdr) == "Codes,Title,Area,Status,New,Open", join(hdr))
check("  ...the count reads Showing N of N", t.count:GetText() == ("Showing %d of %d"):format(#QA.list, #QA.list), t.count:GetText())
local function RowOf(id) for _, r in ipairs(t.rows) do if r:IsShown() and r.id == id then return r end end end
local eng = RowOf("audit-engine")
check("a row's Codes cell shows every code in full; the Title cell the title without them", eng and eng.codes:GetText() == "D28, D56, D57, B263, B264"
  and eng.title:GetText():find("^Combat tracking: hidden buffs are not guessed") and not eng.title:GetText():find("D28", 1, true), eng and (eng.codes:GetText() .. " / " .. eng.title:GetText()))
local look = RowOf("chk-look-1")
check("  ...a title with ordinary words in parentheses is shown whole, no codes", look and look.title:GetText() == "2. Looks and layout (no effect on use) (1 of 7)"
  and look.codes:GetText() == "", look and look.title:GetText())
local chat = RowOf("chat-210-mover-collapse")
check("  ...#210 moves from the title to Codes", chat and chat.codes:GetText() == "#210, D21" and chat.title:GetText() == "Chat: move, resize and hide the chat",
  chat and (chat.codes:GetText() .. " / " .. chat.title:GetText()))
local marked, plain = 0, 0
for _, r in ipairs(t.rows) do if r:IsShown() then
  if r.title:GetText():find("Baseline", 1, true) then marked = marked + 1; if not QA.IsBaseline(r.id) then plain = plain + 1 end end
end end
check("the 10 Baseline rows are marked Baseline in their Title cell, no other row", marked == 10 and plain == 0, marked .. " marked, " .. plain .. " wrongly")
check("Status reads Failed / Passed / Not run, with (rerun) for a result against an older text", RowOf("audit-engine").status:GetText():find("Failed", 1, true)
  and RowOf("bars-cues").status:GetText():find("Passed", 1, true) and RowOf("zz-test-idonly").status:GetText():find("Not run", 1, true)
  and RowOf("group-box").status:GetText():find("Passed", 1, true) and RowOf("group-box").status:GetText():find("(rerun)", 1, true), RowOf("group-box").status:GetText())
check("Status reads Skipped (not Passed) for a run with no Pass and no Fail (Dev Assist 0.7.53)", RowOf("group-nested").status:GetText():find("Skipped", 1, true) ~= nil
  and not RowOf("group-nested").status:GetText():find("Passed", 1, true) and QA.Table.Status("group-nested") == "skipped", RowOf("group-nested").status:GetText())
check("New reads new / changed against the acknowledged build", RowOf("zz-test-new").new:GetText():find("new", 1, true) and RowOf("group-page").new:GetText():find("changed", 1, true)
  and RowOf("group-box").new:GetText() == "", RowOf("group-page").new:GetText())
local okOpen = RowOf("zz-test-idonly")
okOpen.open:GetScript("OnClick")(okOpen.open)
check("Open on a row starts that walkthrough", QA.State() and QA.State().id == "zz-test-idonly" and Wn.stepNo:IsShown() and not t.head:IsShown())
QA.Toggle(); QA.Toggle()
check("  ...back to the list: the table again", Wn:IsShown() and t.head:IsShown() and t.scroll:IsShown() and #t.visible == #QA.list)

-- the default order: area, then the list's own order
local pos = {}
for i, id in ipairs(QA.list) do pos[id] = i end
local okDef = true
for i = 2, #t.visible do
  local a, b = t.visible[i - 1], t.visible[i]
  if a.area > b.area or (a.area == b.area and pos[a.id] > pos[b.id]) then okDef = false end
end
check("default order: by area, then the list's own order", okDef)

-- search over each field
local function ids() return join(t:Ids()) end
local before = Snap()
t:Type("ALPHA walk"); check("search: the title (any capital letters)", ids() == "zz-test-idonly", ids())
t:Type("zz-test-idonly"); check("search: the walkthrough id", ids() == "zz-test-idonly", ids())
t:Type("q902"); check("search: the qa field", ids() == "zz-test-idonly", ids())
t:Type("Q901"); check("search: a code in the title", ids() == "zz-test-idonly", ids())
t:Type("zebra"); check("search: the area", ids() == "zz-test-idonly,zz-test-new", ids())
t:Type("find the unicorn"); check("search: step text, colour codes stripped", ids() == "zz-test-idonly", ids())
t:Type("B263"); check("search: a real QA code (B263) finds audit-engine", set(t:Ids())["audit-engine"] == true, ids())
t:Type("#210"); check("search: #210 finds the chat walkthrough", set(t:Ids())["chat-210-mover-collapse"] == true, ids())
local allMatch = true
for _, e in ipairs(t.visible) do if not e.hay:find("#210", 1, true) then allMatch = false end end
check("  ...and only rows that contain it", allMatch and #t.visible < #QA.list, #t.visible)
check("  ...the count follows", t.count:GetText() == ("Showing %d of %d"):format(#t.visible, #QA.list), t.count:GetText())
t:Type("nothing matches this xyzzy"); check("search: no match, no rows", #t.visible == 0 and not t.rows[1]:IsShown() and t.count:GetText() == "Showing 0 of " .. #QA.list)
t.search:SetText("chat"); t.search:GetScript("OnTextChanged")(t.search, true)
check("typing in the box filters as you type (OnTextChanged)", t.f.q == "chat" and #t.visible > 0 and #t.visible < #QA.list, #t.visible)
t:Type("   "); check("an empty box (spaces only) shows everything", #t.visible == #QA.list)

-- chips
local function click(key) local b = t.chips[key]; b:GetScript("OnClick")(b) end
check("chips: Baseline, one per area, Not run, Passed, Failed, New or changed", t.chips["baseline"] and t.chips["area:Chat"] and t.chips["area:Zebra area"]
  and t.chips["area:Dev Assist"] and t.chips["status:notrun"] and t.chips["status:passed"] and t.chips["status:failed"] and t.chips["new"]
  and t.chips["baseline"]:GetText() == "Baseline" and t.chips["new"]:GetText() == "New or changed")
click("baseline")
local b10 = true
for _, e in ipairs(t.visible) do if not e.baseline then b10 = false end end
check("Baseline: exactly the 10 rows", #t.visible == 10 and b10 and t.chips["baseline"].on and t.count:GetText() == "Showing 10 of " .. #QA.list, #t.visible)
click("area:Chat"); click("area:Dev Assist")
check("areas OR together, AND with Baseline", ids() == "chat-improved-split,perf-settings-click", ids())
click("area:Chat"); click("area:Dev Assist")
check("  ...unclicking them: the 10 again", #t.visible == 10 and not t.chips["area:Chat"].on)
click("status:failed")
check("Baseline AND Failed", ids() == "audit-engine", ids())
click("status:passed")
check("statuses OR together (Failed or Passed)", set(t:Ids())["audit-engine"] and set(t:Ids())["bars-cues"] and #t.visible == 2, ids())
t:Type("progress bars")
check("the search ANDs with the chips", ids() == "bars-cues", ids())
t:Type(""); click("status:failed"); click("status:passed"); click("baseline")
click("status:notrun"); click("area:Zebra area")
check("Not run AND an area", ids() == "zz-test-idonly,zz-test-new", ids())
click("area:Zebra area"); click("status:notrun")
click("new")
check("New or changed: the new and the changed walkthroughs only", ids() == "group-page,zz-test-new", ids())
click("area:Zebra area")
check("  ...AND an area", ids() == "zz-test-new", ids())
t:Type("beta")
t.clear:GetScript("OnClick")(t.clear)
local on = 0
for _, b in pairs(t.chips) do if b.on then on = on + 1 end end
check("Clear: empty search, no chip on, every row back", t.search:GetText() == "" and t.f.q == "" and on == 0 and #t.visible == #QA.list
  and not t.chips["new"].on, on .. " on, " .. #t.visible)

-- sorting
local function hclick(i) local h = t.headers[i]; h:GetScript("OnClick")(h) end
local okSort, why = true, ""
for i, key in ipairs({ "codes", "title", "area", "status", "new" }) do
  local val = TB.SORTVAL[key]
  t.sortKey, t.sortDesc = nil, false
  hclick(i)
  for pass = 1, 2 do
    local desc = pass == 2
    for j = 2, #t.visible do
      local a, b = t.visible[j - 1], t.visible[j]
      local va, vb = val(a), val(b)
      local good = (va == vb and a.rank < b.rank) or (va ~= vb and ((not desc and va < vb) or (desc and va > vb)))
      if not good then okSort = false; why = why .. key .. (desc and " desc" or " asc") .. " at " .. j .. "; " ; break end
    end
    local h = t.headers[i].text:GetText()
    if h ~= (t.cols[i].label .. (desc and "  v" or "  ^")) then okSort = false; why = why .. "header " .. h .. "; " end
    if t.sortKey ~= key or (t.sortDesc and true or false) ~= desc then okSort = false; why = why .. "state " .. key .. "; " end
    if pass == 1 then hclick(i) end
  end
end
check("each column sorts on a header click, a second click reverses it, ties keep the default order (stable), the arrow shows", okSort, why)
t.sortKey, t.sortDesc = nil, false
hclick(2)
local firstAsc = t.visible[1].title
hclick(2)
check("  ...Title A to Z then Z to A", t.visible[#t.visible].title == firstAsc and t.visible[1].title:lower() >= firstAsc:lower(), firstAsc .. " / " .. t.visible[1].title)
check("  ...only the sorted header shows an arrow", t.headers[1].text:GetText() == "Codes" and t.headers[3].text:GetText() == "Area")
check("the Open column is not a sort key", t.headers[6]:GetScript("OnClick") == nil)
hclick(4); t:Type("zebra")
check("search keeps the sort (Status A to Z among the matches)", ids() == "zz-test-idonly,zz-test-new", ids())
t:Clear(); t.sortKey, t.sortDesc = nil, false; t:Refresh()

-- V11: everything inside the window
local wl, wr, wb, wt = Wn:GetLeft(), Wn:GetRight(), Wn:GetBottom(), Wn:GetTop()
local inside = true
local function within(f, n) if f:GetLeft() < wl or f:GetRight() > wr + 0.5 or f:GetBottom() < wb - 0.5 or f:GetTop() > wt + 0.5 then inside = false; why = n end end
why = ""
within(t.head, "header"); within(t.search, "search"); within(t.clear, "clear"); within(t.scroll, "scroll")
for k, b in pairs(t.chips) do within(b, k) end
local okCols = true
for i = 2, #t.cols do if t.cols[i].x < t.cols[i - 1].x + t.cols[i - 1].w then okCols = false end end
local last = t.cols[#t.cols]
check("V11: search row, chips, header and rows inside the window; columns side by side, no overlap", inside and okCols and last.x + last.w <= t.cfg.width
  and t.scroll:GetTop() <= t.head:GetBottom() and t.head:GetTop() <= t.chips["new"]:GetBottom() + 30, why)
local r1 = t.rows[1]
check("  ...row cells inside the row; rows shaded every other line", r1.open:GetRight() <= r1:GetRight() and r1.title:GetLeft() >= r1:GetLeft()
  and t.rows[1].bg._color[4] > 0 and t.rows[2].bg._color[4] == 0)
check("the step page keeps the runner's own size", (function() QA.Start("zz-test-idonly"); local w = Wn:GetWidth(); QA.Toggle(); QA.Toggle(); return w == 660 and Wn:GetWidth() == 900 end)())

-- the review popup has the same table
RV.Show("test")
local rw = RV.Window()
local rt = rw and rw.tbl
check("the review popup has the same table, listing what is new or changed", rt and rt.head:IsShown() and join(rt:Ids()) == "group-page,zz-test-new"
  and rt.headers[1].text:GetText() == "Codes", rt and join(rt:Ids()))
rt:Type("beta")
check("  ...its search filters its rows", join(rt:Ids()) == "zz-test-new" and rt.count:GetText() == "Showing 1 of 2", rt.count:GetText())
local rb = rt.rows[1]
local rwl, rwr, rwb = rw:GetLeft(), rw:GetRight(), rw:GetBottom()
check("  ...table above the tick box, inside the window", rt.scroll:GetBottom() >= rw.dont:GetTop() - 0.5 and rt.head:GetRight() <= rwr and rt.head:GetLeft() >= rwl
  and rt.chips["new"]:GetRight() <= rwr, rt.scroll:GetBottom() .. " vs " .. rw.dont:GetTop())
rb.open:GetScript("OnClick")(rb.open)
check("  ...Open goes to the runner on that walkthrough", QA.State().id == "zz-test-new" and not rw:IsShown())
QA.Window():Hide()
rt:Clear()

-- nothing of it is saved
check("nothing of the search, chips or sort was written to CueRulesDB or XayaUIDevAssistDB", (function()
  local now = Snap()
  -- the review popup's own bookkeeping (lastShown / lastOpened, from before this build) is the only difference allowed
  local function strip(s) return (s:gsub("DevAssist%.review%.lastShown[^\n]*\n?", ""):gsub("DevAssist%.review%.lastOpened[^\n]*\n?", "")) end
  return strip(now) == strip(before)
end)())
local found = {}
for _, line in ipairs(Dump(rawget(_G, "CueRulesDB"), "CueRulesDB", Dump(rawget(_G, "XayaUIDevAssistDB"), "DevAssist"))) do
  local path = line:match("^([^=]*)") or line
  if not (path:find(".fps.", 1, true) or path:find(".results.", 1, true)) then
    for comp in path:gmatch("[^%.]+") do
      local c = comp:lower()
      if c:find("search", 1, true) or c:find("chip", 1, true) or c == "sortkey" or c == "sortdesc" then found[#found + 1] = line; break end
    end
  end
end
check("  ...no saved key about a search, chip or sort", #found == 0, join(found))

-- V22: the walkthrough's own checks on the real table
local def = QA.walks["review-search"]
check("the review-search walkthrough is registered with pre-fill (V22)", def and def.prefill and def.qa == "J32" and #def.steps == 8)
if def then
  QA.Start("review-search")
  local verdicts = {}
  for i = 1, 7 do
    local st = def.steps[i]
    if st.setup then pcall(st.setup) end
    if i == 7 then local rt2 = RV.Window().tbl; rt2:Type("beta"); rt2:ToggleChip("baseline"); rt2.clear:GetScript("OnClick")(rt2.clear) end
    local ok, good, note = pcall(st.check)
    verdicts[#verdicts + 1] = i .. "=" .. tostring(ok and good) .. (ok and good and "" or (" (" .. tostring(note) .. ")"))
  end
  local allP = true
  for _, v in ipairs(verdicts) do if not v:find("=true", 1, true) then allP = false end end
  check("  ...every check the addon can judge says Pass on the real table (search, Baseline, OR / AND, a header click changes the order, reverse, Clear)",
    allP, join(verdicts))
  check("  ...the last step is a question for her (noVerdict)", def.steps[8].noVerdict == true)
end
return R
end
'''

# a session that opens nothing: what the saved file holds without the table
PLAIN = r'''
return function(W, L)
L.startup()
''' + COMMON + r'''
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", false, true); W.tick(0.5, 10)
return R
end
'''


def session(L_src, saved):
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": saved}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(L_src, world, loader)
    out, issues = loader.logout()
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    results.append(("the saved file can be written by the game" + ("" if len(issues) == 0 else "  [%s]" % issues[1]), len(issues) == 0))
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    return results, H.lua_to_py(out), errs


def keypaths(v, path=""):
    out = set()
    if isinstance(v, dict):
        for k, x in v.items():
            out |= keypaths(x, path + "." + str(k))
    elif isinstance(v, list):
        out.add(path + "[]")
        for x in v:
            out |= keypaths(x, path + "[]")
    else:
        out.add(path)
    return out


def main():
    bad, n, allErrs = 0, 0, []
    results, savedMain, errs = session(MAIN, {})
    allErrs += errs
    for name, ok in results:
        n += 1
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    _, savedPlain, errs2 = session(PLAIN, {})
    allErrs += errs2
    a = keypaths(savedMain.get("CueRulesDB") if isinstance(savedMain, dict) else None)
    b = keypaths(savedPlain.get("CueRulesDB") if isinstance(savedPlain, dict) else None)
    extra = sorted(a - b)
    n += 1
    used = len(results) > 10   # the first session got past "Dev Assist has the walkthrough table" and used it
    ok = used and len(extra) == 0 and len(a) > 0
    print(("PASS " if ok else "FAIL ") + "after using the table, the saved CueRulesDB has no key a session without the table lacks"
          + ("" if ok else "  [%s]" % (", ".join(extra[:8]) if used else "the table was never used")))
    bad += 0 if ok else 1
    for e in allErrs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (n, bad, len(allErrs)))
    sys.exit(1 if bad or allErrs else 0)


if __name__ == "__main__":
    main()
