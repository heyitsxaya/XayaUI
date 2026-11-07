#!/usr/bin/env python3
"""The function audit's in-game QA walkthroughs (XayaUI_DevAssist 0.7.19, QAWalks-audit.lua; standing rule V21, Xaya 2026-11-07:
"make sure every feature or significant change to the codebase / bug report fixes have an in game qa test walk through with pre-fill
confirmation options or data capturing").
Checks, on the real addons (Dev Assist on) in the stand-in game:
- every audit walkthrough is registered with prefill = true; every step's Do it for me and check run without a Lua error;
- the checks the stand-in can answer give the right verdict on the fixed code: minimap rows (O-100, D11), the arrangement holds still
  (D18), Snap to a missing frame keeps the position (D19), Recycle Bin restore brings every rule back (D55), the built-in categories
  (D40, fresh profile), the whole-word filter (D37), no British spelling in the texts it reads (FA-16);
- each walkthrough's last step removes its test data and puts back what it switched (QA audit group gone; Notepad state restored).
The Notepad steps need the game's real EditBox (HighlightText + Insert replacing the selection), which the stand-in does not model:
here they only have to run without an error.
Run: python3 tests/qa_walk_audit_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local QA, ns = rawget(_G, "XayaUI_DevQA"), rawget(_G, "XayaUI_NS")
if not QA then check("Dev Assist QA framework", false); return R end
local ids = { "audit-notepad-format", "audit-notepad-restore", "audit-minimap-rows", "audit-groups", "audit-backup-replace", "audit-talents-init", "audit-chat", "audit-spelling", "audit-theme", "audit-bin-words", "audit-engine" }
for _, id in ipairs(ids) do
  local d = QA.walks[id]
  check(id .. ": registered with prefill", d ~= nil and d.prefill == true and #d.steps >= 1, d and d.prefill)
end
local function Run(id, i)
  local st = QA.walks[id].steps[i]
  local okS, errS = true, nil
  if st.setup then okS, errS = pcall(st.setup); W.tick(0.05, 2) end
  local okC, v, note = pcall(st.check)
  return okS, errS, okC, v, note
end
-- every step runs without a Lua error (a setup may refuse with a message, e.g. the Notepad being off: reported, not an error)
for _, id in ipairs(ids) do
  local d = QA.walks[id]
  for i = 1, #d.steps do
    local okS, errS, okC, v, note = Run(id, i)
    check(("%s step %d: check runs"):format(id, i), okC, okC and "" or v)
  end
end
-- the verdicts the stand-in can answer (fresh runs)
local function V(id, i) local _, _, okC, v, note = Run(id, i); return okC and v, note end
local v, n = V("audit-minimap-rows", 1); check("O-100 / D11 minimap rows: verdict Pass", v == true, n)
v, n = V("audit-groups", 1); check("D18 arrangement holds still: verdict Pass", v == true, n)
v, n = V("audit-groups", 2); check("D19 Snap to a missing frame: verdict Pass", v == true, n)
v, n = V("audit-groups", 5); check("D55 Recycle Bin restore: verdict Pass", v == true, n)
v, n = V("audit-groups", 6); check("audit-groups last step: the QA audit group is gone", v == true, n)
local left = 0; for _, r in ipairs(ns.rules) do if r.qaAudit and r.folder and ns.FolderById and ns.FolderById(r.folder) and ns.FolderById(r.folder).qaAudit then left = left + 1 end end
check("  ...no sample rule left in a QA audit group", left == 0, left)
v, n = V("audit-backup-replace", 1); check("D40 built-in categories present on a fresh profile: verdict Pass", v == true, n)
v, n = V("audit-chat", 1); check("D37 whole-word filter: verdict Pass", v == true, n)
v, n = V("audit-spelling", 1); check("FA-16 no British spelling in the texts it reads: verdict Pass", v == true, n)
-- the theme walkthrough: asks, Cancel keeps, Save As Copy, cleanup puts the theme back
do
  local before = ns.Theme.Export()
  local d = QA.walks["audit-theme"]
  local function step(i) if d.steps[i].setup then pcall(d.steps[i].setup) end; W.tick(0.05, 2); return d.steps[i].check() end
  local function click(i) local dlg = rawget(_G, "XayaUIThemeAsk"); local b = dlg and dlg.btns[i]; if b then b:GetScript("OnClick")(b) end end
  local v1, n1 = step(1)
  check("FA-4 theme walkthrough step 1: the ask dialog is up, theme unchanged (verdict Pass)", v1 == true, n1)
  click(2); local v1b, n1b = d.steps[1].check()
  check("FA-4 ...after Cancel: colors kept (verdict Pass)", v1b == true, n1b)
  local v2, n2 = step(2)
  check("FA-8 step 2: Replace / Save As Copy / Cancel in that order (verdict Pass)", v2 == true, n2)
  click(2); local v2b, n2b = d.steps[2].check()
  check("FA-8 ...after Save As Copy: the copy is saved, the original unchanged (verdict Pass)", v2b == true, n2b)
  local v3, n3 = step(3); check("FA-13 step 3: Reset everything names Class colors (verdict Pass)", v3 == true, n3)
  local v4, n4 = step(4); check("theme walkthrough last step: QA themes gone, theme back", v4 == true and ns.Theme.Export() == before, n4)
end
local vb, nb = QA.walks["audit-bin-words"].steps[2].check(); check("D8 words walkthrough: verdict Pass", vb == true, nb)
do
  local M = ns.AuraModel; local was = M.PresenceEnabled(); M.SetSetting("presence", false)
  local ve, ne = QA.walks["audit-engine"].steps[1].check(); check("D28 engine walkthrough with the box off: verdict Pass", ve == true, ne)
  M.SetSetting("presence", was)
end
-- audit D36 (Dev Assist 0.7.19): the debug-report walkthrough leaves no test error behind, and raises nothing through the game's handler
do
  local d = QA.walks["debug-report"]
  if d then
    if ns.RecordError then ns.RecordError("a real XayaUI error that must stay", nil, "XayaUI", "XUI-E001") end
    local handled = 0
    local origH = geterrorhandler; local h0 = origH and origH()
    local spy = function(e) if tostring(e):find("not XayaUI", 1, true) then handled = handled + 1 end; if h0 then return h0(e) end end
    if seterrorhandler and origH then seterrorhandler(spy) end
    for i = 1, #d.steps do local st = d.steps[i]; if st.setup then pcall(st.setup) end; W.tick(0.05, 2) end
    if seterrorhandler and h0 then seterrorhandler(h0) end
    local left, real = false, false
    for _, e in ipairs(ns.ErrorEntries()) do
      if tostring(e.msg):find("QA walkthrough test error", 1, true) then left = true end
      if tostring(e.msg):find("a real XayaUI error that must stay", 1, true) then real = true end
    end
    check("D36 debug-report walkthrough: its test error is gone after the last step, your real errors stay", not left and real, tostring(left) .. "/" .. tostring(real))
    check("D36 ...and the \"not XayaUI\" case is never raised through the game's error handler", handled == 0, handled)
    local v2, n2 = d.steps[2].check()
    check("D36 the classification check still answers (XayaUI file recorded, other folder not)", n2 ~= nil, n2)
  else
    check("D36 debug-report walkthrough is registered", false)
  end
end
-- the Notepad walkthrough's last step puts the Notepad back
local db = ns.notepadDB
if db then
  local before = { shown = db.shown and true or false, format = db.format and true or false, n = #db.notes }
  Run("audit-notepad-format", 1)
  local made = #db.notes == before.n + 1
  local d = QA.walks["audit-notepad-format"]; Run("audit-notepad-format", #d.steps)
  check("Notepad walkthrough: step 1 adds one note, the last step removes it and restores shown / Formatting tools",
    made and #db.notes == before.n and (db.shown and true or false) == before.shown and (db.format and true or false) == before.format,
    ("made %s; notes %d -> %d; shown %s -> %s; format %s -> %s"):format(tostring(made), before.n, #db.notes, tostring(before.shown), tostring(db.shown), tostring(before.format), tostring(db.format)))
end
return R
end
'''


def main():
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    # the debug-report walkthrough raises its own XayaUI test error on purpose (that is what its step checks): not a failure here
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1) if "QA walkthrough test error" not in str(world.errors[i])]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
