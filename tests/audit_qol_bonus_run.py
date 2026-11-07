#!/usr/bin/env python3
"""Function audit 2026-11-07 (docs/process/FUNCTION-AUDIT-2026-11-07.md), QoL / Bonus rows that have no closer test file:
  D17 (QoL, Character Toolkit): with "Show the panel" off (toolkit on), the panel's stat / unit events and SPELL_UPDATE_COOLDOWN are
      not registered and a cast does no GCD read (V14); the slot overlays keep their events while they are on.
  D50 (Bonus, Data Panels): "Remove block" before the "Editing block" slider was ever used removes the block without a Lua error.
  D52 (Bonus, Enhanced Tooltips): with "Aura IDs" off, a spell / item hover runs no aura lookup (TT.AurasFor) and writes no saved
      db.selfAura (V14); with it on, it still does.
  D53 (Bonus, Notepad Share): the Share window sends the note it named when it opened, not the note that is current at click time.
The Shopping List rows (FA-7, D13-D16) are in tests/shopping_list_run.py; D49 / D51 in tests/calculator_run.py.
Part 1 runs in the Character Toolkit stand-in (tests/char_toolkit_world.lua); part 2 loads the real XayaUI, XayaUI_Media and
XayaUI_Bonus in the whole-addon stand-in game (tests/harness). Every check fails on the code before the fix (see the debug log
debug-log/2026-11-07-*-audit-qol-bonus-fixes.md) unless it is marked "(as before)".
Run from the repo root: python3 tests/audit_qol_bonus_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "harness"))
from lua51 import runtime as LuaRuntime  # noqa: E402
import run as H  # noqa: E402
ROOT = os.path.join(HERE, "..")


def P(rel): return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"


# ---------------------------------------------------------------------------------------------------------------------------------
# Part 1: D17, Character Toolkit
# ---------------------------------------------------------------------------------------------------------------------------------
def part1():
    lua = LuaRuntime()
    lua.execute(r'''
assert(loadfile(__WORLD__))()
assert(loadfile(__MOD__))("XayaUI", ns)
assert(loadfile(__COMPAT__))("XayaUI", ns)
assert(loadfile(__SM__))("XayaUI_QoL", ns)
assert(loadfile(__CM__))("XayaUI_QoL", ns)
assert(loadfile(__CT__))("XayaUI_QoL", ns)
ns.FireReady()
local CM = ns.CharModel
local gcdReads = 0
local rawGCD = CM.ReadGCD
CM.ReadGCD = function(...) gcdReads = gcdReads + 1; return rawGCD(...) end
local function registered(e) for _, f in ipairs(created) do if f.events and f.events[e] then return true end end; return false end
local c = ns.CharToolkit_Cfg()
c.enabled, c.panel, c.overlays = true, false, false
ns.CharToolkit_Apply()
check("D17: toolkit on, panel part off: SPELL_UPDATE_COOLDOWN is not registered", not registered("SPELL_UPDATE_COOLDOWN"))
check("  ...no unit stat event (UNIT_STATS, UNIT_SPELL_HASTE) is registered", not registered("UNIT_STATS") and not registered("UNIT_SPELL_HASTE"))
check("  ...no stat event (COMBAT_RATING_UPDATE, MASTERY_UPDATE) is registered", not registered("COMBAT_RATING_UPDATE") and not registered("MASTERY_UPDATE"))
fire("SPELL_UPDATE_COOLDOWN")
check("  ...a cast does no GCD read for the hidden panel", gcdReads == 0, gcdReads)
c.overlays = true
ns.CharToolkit_Apply()
check("  ...slot overlays on: their events are registered (PLAYER_EQUIPMENT_CHANGED, SOCKET_INFO_UPDATE)", registered("PLAYER_EQUIPMENT_CHANGED") and registered("SOCKET_INFO_UPDATE"))
check("  ...and still no panel event", not registered("SPELL_UPDATE_COOLDOWN") and not registered("UNIT_STATS"))
c.panel = true
ns.CharToolkit_Apply()
check("(as before) panel part on: SPELL_UPDATE_COOLDOWN, UNIT_STATS and COMBAT_RATING_UPDATE are registered", registered("SPELL_UPDATE_COOLDOWN") and registered("UNIT_STATS") and registered("COMBAT_RATING_UPDATE"))
local before = gcdReads
fire("SPELL_UPDATE_COOLDOWN")
check("(as before) ...and a cast reads the GCD", gcdReads == before + 1, gcdReads - before)
c.panel = false
ns.CharToolkit_Apply()
check("  ...panel part off again: its events are let go at once", not registered("SPELL_UPDATE_COOLDOWN") and not registered("UNIT_STATS") and registered("PLAYER_EQUIPMENT_CHANGED"))
c.enabled = false
ns.CharToolkit_Apply()
check("(as before) toolkit off: nothing of it is registered", not registered("PLAYER_EQUIPMENT_CHANGED") and not registered("PLAYER_SPECIALIZATION_CHANGED"))
'''.replace("__WORLD__", P("tests/char_toolkit_world.lua")).replace("__MOD__", P("XayaUI/Modules.lua")).replace("__COMPAT__", P("XayaUI/Compat.lua"))
       .replace("__SM__", P("XayaUI_QoL/StatMath.lua")).replace("__CM__", P("XayaUI_QoL/CharacterModel.lua")).replace("__CT__", P("XayaUI_QoL/CharacterToolkit.lua")))
    return int(lua.eval("n")), int(lua.eval("fails"))


# ---------------------------------------------------------------------------------------------------------------------------------
# Part 2: D50, D52, D53 in the whole-addon stand-in
# ---------------------------------------------------------------------------------------------------------------------------------
LUA2 = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
check("(sanity) core and Bonus loaded", ns ~= nil and ns.TT ~= nil and ns.BuildDataPanelsTab ~= nil and ns.NotepadShare_OpenShare ~= nil)
if not (ns and ns.TT and ns.BuildDataPanelsTab) then return R end
local noop = function() end

-- D50: Data Panels "Remove block" before "Editing block" was used ----------------------------------------------------------------
local tab = ns.BuildDataPanelsTab(noop)
local blocks = tab.args.general.args.left.args.blocks.args
local cfg = CueRulesDB.dataPanels.bl
check("(sanity) the left panel has 3 blocks", tonumber(cfg.slots) == 3, cfg.slots)
local ok, err = pcall(blocks.remove.func)
check("D50: Remove block with the Editing block slider never used: no Lua error", ok, err)
check("  ...the block is removed (3 -> 2)", tonumber(cfg.slots) == 2, cfg.slots)
check("  ...the Editing block slider reads block 1 of 2", blocks.idx.get() == 1, blocks.idx.get())
blocks.idx.set(nil, 2)
local ok2, err2 = pcall(blocks.remove.func)
check("(as before) Remove block on block 2 of 2 after using the slider: removed, the slider follows (1)", ok2 and tonumber(cfg.slots) == 1 and blocks.idx.get() == 1, err2 or blocks.idx.get())

-- D52: Enhanced Tooltips, "Aura IDs" off ------------------------------------------------------------------------------------------
local TT = ns.TT
local db = TT.DB()
db.ids.enabled, db.ids.spell, db.ids.item, db.ids.aura = true, true, true, false
db.selfAura = nil
local calls = 0
local rawAF = TT.AurasFor
TT.AurasFor = function(...) calls = calls + 1; return rawAF(...) end
local SPELL, ITEM = { key = "spell", label = "Spell ID" }, { key = "item", label = "Item ID" }
GameTooltip:ClearLines()
TT.OnIDData(GameTooltip, { id = 133 }, SPELL)
TT.OnIDData(GameTooltip, { id = 6948 }, ITEM)
check("D52: Aura IDs off: a spell and an item hover run no aura lookup", calls == 0, calls)
check("  ...and write no saved selfAura table", db.selfAura == nil)
db.ids.aura = true
local callsBefore = calls
TT.OnIDData(GameTooltip, { id = 133 }, SPELL)
check("(as before) Aura IDs on: the hover looks the auras up (and keeps selfAura)", calls == callsBefore + 1 and type(db.selfAura) == "table", calls - callsBefore)
TT.AurasFor = rawAF

-- D53: Notepad Share sends the note it named when it opened ----------------------------------------------------------------------
ns.Notepad_SetShown(true)
local npdb = ns.notepadDB
ns.Notepad_New("D53 first note: the one to share")
local firstID = npdb.current
ns.Notepad_New("D53 second note: switched to after opening Share")
-- back to the first note, open Share on it, then switch to the second note
ns.Notepad_Prev()
check("(sanity) the first note is current", npdb.current == firstID and ns.Notepad_CurrentText() == "D53 first note: the one to share", ns.Notepad_CurrentText())
ns.NotepadShare_OpenShare()
local f = rawget(_G, "XayaUINoteShare")
check("(sanity) the Share window is open", f ~= nil and f:IsShown())
local named = f and f.what:GetText() or ""
ns.Notepad_Next()
check("(sanity) the second note is current now", ns.Notepad_CurrentText() == "D53 second note: switched to after opening Share", ns.Notepad_CurrentText())
local sent
local rawSend = ns.NotepadShare_Send
ns.NotepadShare_Send = function(text, ...) sent = text; return true end
if f then f.send:GetScript("OnClick")(f.send) end
ns.NotepadShare_Send = rawSend
check("D53: Send sends the note the window named when it opened", sent == "D53 first note: the one to share", sent)
check("  ...the window's name line named that note", named:find("D53 first note", 1, true) ~= nil, named)
-- the named note deleted while the window is open: nothing is sent (never another note)
ns.Notepad_Prev(); ns.NotepadShare_OpenShare(); ns.Notepad_Delete()
sent = nil
ns.NotepadShare_Send = function(text, ...) sent = text; return true end
if f then f.send:GetScript("OnClick")(f.send) end
ns.NotepadShare_Send = rawSend
check("  ...its note deleted meanwhile: nothing is sent, the window says why", sent == nil and f:IsShown() and (f.status:GetText() or ""):find("deleted", 1, true) ~= nil, sent or f.status:GetText())
f:Hide()
return R
end
'''


def part2():
    folders = H.find_addons()
    enabled = [n for n in folders if n in ("XayaUI", "XayaUI_Media", "XayaUI_Bonus")]
    saved = {"XayaUI": {"CueRulesDB": {
        "dataPanels": {"general": {"enabled": True}, "bl": {"enabled": True, "slots": 3}},
        "notepad": {"shown": True},
        "ui": {"consoleAutoOpen": False}}}}
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    w = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), w,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": saved}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA2, w, loader)
    total, bad = 0, 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("ok:   " if ok else "FAIL: ") + name)
        total += 1
        if not ok:
            bad += 1
    for i in range(1, len(w.errors) + 1):
        print("FAIL: Lua error in the game stand-in: %s" % str(w.errors[i])[:700])
        total += 1
        bad += 1
    return total, bad


# ---------------------------------------------------------------------------------------------------------------------------------
# Part 3: the in-game QA walkthroughs (XayaUI_DevAssist/QAWalks-audit-qol-bonus.lua) on every addon in the stand-in: each is
# registered with prefill; every step runs without a Lua error; the verdicts the stand-in can answer are Pass on the fixed code;
# each last step removes its test data and puts back what it changed. (The file is loaded by hand here: the parent session adds it
# to Dev Assist's .toc.)
# ---------------------------------------------------------------------------------------------------------------------------------
LUA3 = r'''
return function(W, L, WALKSRC)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local QA, ns = rawget(_G, "XayaUI_DevQA"), rawget(_G, "XayaUI_NS")
if not QA then check("Dev Assist QA framework", false); return R end
assert(loadstring(WALKSRC, "@Interface/AddOns/XayaUI_DevAssist/QAWalks-audit-qol-bonus.lua"))()
local ids = { "audit-shopping-list", "audit-shopping-ah", "audit-char-toolkit-events", "audit-calculator", "audit-data-panels-remove",
  "audit-tooltips-aura-off", "audit-notepad-share" }
for _, id in ipairs(ids) do
  local d = QA.walks[id]
  check(id .. ": registered with prefill, order 330+", d ~= nil and d.prefill == true and #d.steps >= 1 and (d.order or 0) >= 330, d and d.order)
end
-- what the walkthroughs must leave as it was
local shop = ns.Service("shoppingList")
local c = shop.Cfg()
local ct = CueRulesDB.characterToolkit
local before = { buy = #c.buy, enabled = c.enabled, panel = c.panel, ctPanel = ct and ct.panel, notes = #(ns.notepadDB and ns.notepadDB.notes or {}),
  aura = ns.Service("tooltipsDebug").TT.DB().ids.aura, slots = CueRulesDB.dataPanels and CueRulesDB.dataPanels.bl and CueRulesDB.dataPanels.bl.slots,
  hist = #(CueRulesDB.calculator and CueRulesDB.calculator.history or {}) }
local verdict = {}
for _, id in ipairs(ids) do
  local d = QA.walks[id]
  verdict[id] = {}
  for i = 1, #d.steps do
    local st = d.steps[i]
    local okS, errS = true, nil
    if st.setup then okS, errS = pcall(st.setup); W.tick(0.05, 2) end
    local okC, v, note = pcall(st.check)
    check(("%s step %d: Do it for me and the check run without a Lua error"):format(id, i), okS and okC, (not okS and errS) or (not okC and v) or "")
    verdict[id][i] = { okC and v, note }
  end
end
local function P(id, i, what) local r = verdict[id][i]; check(what .. ": verdict Pass", r and r[1] == true, r and r[2]) end
P("audit-shopping-list", 1, "FA-7 a default set for this character only")
P("audit-shopping-list", 3, "D13 Forget: nothing re-counted")
P("audit-shopping-list", 4, "D14 To buy adds up (1 + 2 = 3)")
P("audit-shopping-list", 5, "D15 /xui shop with the Reskin tab off changes nothing")
P("audit-shopping-list", 6, "shopping list last step: put back")
P("audit-char-toolkit-events", 1, "D17 panel part off: no panel event")
P("audit-char-toolkit-events", 2, "char toolkit last step: put back")
P("audit-calculator", 1, "D49 1 / 3 x 3 = 1")
P("audit-calculator", 2, "D49 1e-07 x 10")
P("audit-calculator", 3, "D51 12kx3")
P("audit-calculator", 4, "calculator last step: put back")
P("audit-data-panels-remove", 1, "D50 Remove block")
P("audit-data-panels-remove", 2, "data panels last step: put back")
P("audit-tooltips-aura-off", 1, "D52 Aura IDs off: no lookup (nothing hovered)")
P("audit-tooltips-aura-off", 3, "tooltips last step: put back")
P("audit-notepad-share", 1, "D53 the Share window keeps note A")
P("audit-notepad-share", 3, "notepad share last step: put back")
check("everything put back: To buy, Shopping List on / off and panel, Character Toolkit panel, notes, Aura IDs, Left Panel blocks, saved sums",
  #c.buy == before.buy and c.enabled == before.enabled and c.panel == before.panel and (ct and ct.panel) == before.ctPanel
  and #(ns.notepadDB and ns.notepadDB.notes or {}) == before.notes and ns.Service("tooltipsDebug").TT.DB().ids.aura == before.aura
  and (CueRulesDB.dataPanels and CueRulesDB.dataPanels.bl and CueRulesDB.dataPanels.bl.slots) == before.slots
  and #(CueRulesDB.calculator and CueRulesDB.calculator.history or {}) == before.hist,
  ("buy %d/%d enabled %s/%s ctPanel %s/%s notes %d/%d slots %s/%s hist %d/%d"):format(#c.buy, before.buy, tostring(c.enabled), tostring(before.enabled),
    tostring(ct and ct.panel), tostring(before.ctPanel), #(ns.notepadDB and ns.notepadDB.notes or {}), before.notes,
    tostring(CueRulesDB.dataPanels and CueRulesDB.dataPanels.bl and CueRulesDB.dataPanels.bl.slots), tostring(before.slots),
    #(CueRulesDB.calculator and CueRulesDB.calculator.history or {}), before.hist))
return R
end
'''


def part3():
    folders = H.find_addons()
    saved = {"XayaUI": {"CueRulesDB": {
        "characterToolkit": {"enabled": True, "panel": True},
        "dataPanels": {"general": {"enabled": True}, "bl": {"enabled": True, "slots": 2}},
        "notepad": {"shown": False},
        "calculator": {"history": ["1+1 = 2"]},
        "ui": {"consoleAutoOpen": False}}}}
    src = open(os.path.join(ROOT, "XayaUI_DevAssist", "QAWalks-audit-qol-bonus.lua"), encoding="utf-8").read()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    w = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), w, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": saved}))
    res = L.eval("function(src, W, Ld, ws) return loadstring(src)()(W, Ld, ws) end")(LUA3, w, loader, src)
    total, bad = 0, 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("ok:   " if ok else "FAIL: ") + name)
        total += 1
        if not ok:
            bad += 1
    for i in range(1, len(w.errors) + 1):
        print("FAIL: Lua error in the game stand-in: %s" % str(w.errors[i])[:700])
        total += 1
        bad += 1
    return total, bad


n1, f1 = part1()
n2, f2 = part2()
n3, f3 = part3()
print("%d checks, %d failed" % (n1 + n2 + n3, f1 + f2 + f3))
sys.exit(1 if f1 + f2 + f3 else 0)
