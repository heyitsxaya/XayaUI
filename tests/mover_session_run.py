#!/usr/bin/env python3
"""The mover view's held moves, Save / Cancel, temporary group lock, draft and arrow-key nudges (P4 / P5; core 0.6.55).
Xaya 2026-11-06: "arrow-key nudges yes; moves held until Save"; her answer (question flow): "lock icon in mover tool allows for a
temporary lock to account for potentially multiple rule groups stacked on top of each other; does not force a save. exiting out of
mover mode first creates a prompt to cancel or commit move changes. create a temp layout in drafts in case of game crash or something
which auto-deletes after a user clicked save".
Checks, on the real addons in the stand-in game:
- V14: no key frame before the mover view is first opened;
- opening it keeps every position aside (the draft); leaving with no move asks nothing; leaving after moves asks Save / Cancel and
  stays open until answered (Escape does not throw moves away); Cancel puts displays and groups back exactly; Save keeps them; the
  draft is deleted either way;
- the lock on a group's mover tag: its displays let the mouse through and do not drag; the group does not nudge; it ends with the view;
- arrow keys nudge the last clicked display or group by 1 (Shift 10), other keys reach the game, nothing in combat;
- a draft left by a /reload without Save: a prompt at login; Cancel moves puts them back; a draft with no moves is dropped silently.
Old code: no ns.MoverExit / ns.MoverNudge: those checks fail, and locking after a move never asks.
Run: python3 tests/mover_session_run.py   (Lua 5.1 via lupa)."""
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
local ns = rawget(_G, "XayaUI_NS")
check("core has the mover session", ns and ns.MoverExit and ns.MoverNudge and ns.SetMoverTempLock and ns.MoverChanges)
if not (ns and ns.MoverExit) then return R end
local f = ns.NewFolder("Mover test")
f.cX, f.cY = 100, 50
local function mk(name, x, y)
  local r = ns.NewRule(); r.name = name; r.folder = f.id; r.enabled = true
  r.visual = r.visual or {}; r.visual.enabled = true; r.visual.x, r.visual.y = x, y; r.visual.size = 40
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  ns.runtime = ns.runtime or {}; ns.runtime[r] = { active = true, lastPlay = 0, visualWanted = true }
  return r
end
local A, B = mk("Mover A", -60, 0), mk("Mover B", 60, 0)
ns.SetPreview({ A, B }, "visual", true)
ns.RefreshAllVisuals(); W.tick(0.1, 2)
check("V14: no key frame before the mover view is opened", rawget(_G, "XayaUIMoverKeys") == nil)

-- open, nothing moved, leave: no question
ns.ToggleUnlock(); W.tick(0.05, 2)
check("opening the mover view keeps every position aside (the draft)", ns.unlocked and type(CueRulesDB.moverDraft) == "table" and #CueRulesDB.moverDraft.rules >= 2)
check("  ...and shows the key frame for the arrow keys", rawget(_G, "XayaUIMoverKeys") and XayaUIMoverKeys:IsShown())
W.popup = nil
ns.ToggleUnlock(); W.tick(0.05, 2)
check("leaving with no move asks nothing and locks", not ns.unlocked and W.popup == nil and CueRulesDB.moverDraft == nil, W.popup)
check("  ...the key frame hides", not XayaUIMoverKeys:IsShown())

-- moves, then Cancel
ns.ToggleUnlock(); W.tick(0.05, 2)
local keys = XayaUIMoverKeys
local prop
keys.SetPropagateKeyboardInput = function(self, v) prop = v end
local down = keys:GetScript("OnKeyDown")
ns.MoverSelect("display", A)
down(keys, "RIGHT")
check("P4: Right arrow nudges the selected display 1 pixel, and the key does not reach the game", A.visual.x == -59 and prop == false, A.visual.x)
IsShiftKeyDown = function() return true end
down(keys, "UP")
IsShiftKeyDown = function() return false end
check("  ...Shift + Up: 10 pixels", A.visual.y == 10, A.visual.y)
down(keys, "A")
check("  ...any other key reaches the game", prop == true and A.visual.x == -59)
W.combat = true; down(keys, "LEFT"); W.combat = false
check("  ...nothing in combat", A.visual.x == -59)
ns.MoverSelect("group", f); down(keys, "DOWN")
check("  ...a group last clicked nudges as a whole", f.cY == 49, f.cY)
local fa = ns.DisplayFrame(A)
local l1 = fa:GetLeft()
W.popup = nil
ns.ToggleUnlock(); W.tick(0.05, 2)
check("P5: leaving after moves asks first and stays open", ns.unlocked and W.popup == "XAYAUI_MOVER_EXIT", W.popup)
local dlg = StaticPopupDialogs.XAYAUI_MOVER_EXIT
check("  ...the prompt offers Save moves / Cancel moves; Escape does not close it", dlg and dlg.button1 == "Save moves" and dlg.button2 == "Cancel moves" and dlg.hideOnEscape == false)
local called
dlg.OnCancel(nil, { cancel = function() called = "cancel" end }, "clicked")
dlg.OnAccept(nil, { save = function() called = (called or "") .. "+save" end })
check("  ...its buttons call Cancel and Save", called == "cancel+save", called)
ns.MoverExit("cancel"); W.tick(0.05, 2)
check("Cancel moves: the display and the group are back exactly", A.visual.x == -60 and A.visual.y == 0 and f.cX == 100 and f.cY == 50,
  ("%s %s %s %s"):format(tostring(A.visual.x), tostring(A.visual.y), tostring(f.cX), tostring(f.cY)))
check("  ...on screen too", fa:GetLeft() < l1 - 0.5, ("%s / %s"):format(tostring(fa:GetLeft()), tostring(l1)))
check("  ...the draft is deleted and the view is locked", CueRulesDB.moverDraft == nil and not ns.unlocked)

-- moves, then Save
ns.ToggleUnlock(); W.tick(0.05, 2)
ns.MoverSelect("display", B); ns.MoverNudge(5, 0)
ns.ToggleUnlock(); ns.MoverExit("save"); W.tick(0.05, 2)
check("Save moves: the move is kept and the draft deleted", B.visual.x == 65 and CueRulesDB.moverDraft == nil and not ns.unlocked, B.visual.x)

-- the temporary lock
ns.ToggleUnlock(); W.tick(0.05, 2)
local fb = ns.DisplayFrame(B)
check("unlocked: the displays take the mouse", fb:IsMouseEnabled() == true)
ns.SetMoverTempLock(f, true); W.tick(0.05, 2)
check("the lock icon locks the group for now: its displays let the mouse through", fb:IsMouseEnabled() == false)
local started = false
local oldSM = fb.StartMoving; fb.StartMoving = function() started = true end
fb:GetScript("OnDragStart")(fb)
fb.StartMoving = oldSM
check("  ...and do not drag", not started)
ns.MoverSelect("group", f)
check("  ...the locked group does not nudge", ns.MoverNudge(3, 0) == false and f.cX == 100)
check("  ...nothing is saved by locking", #ns.MoverChanges() == 0)
ns.ToggleUnlock(); W.tick(0.05, 2)
check("  ...it ends with the mover view", not ns.IsMoverTempLocked(f) and not ns.unlocked)
ns.ToggleUnlock(); W.tick(0.05, 2)
check("  ...and the next mover view starts with nothing locked", fb:IsMouseEnabled() == true)
ns.ToggleUnlock(); W.tick(0.05, 2)

-- a draft left by a /reload without Save
ns.ToggleUnlock(); W.tick(0.05, 2)
ns.MoverSelect("display", A); ns.MoverNudge(0, 7)
ns.unlocked = false   -- (as after a /reload: the view is closed, the moved data and the draft were saved)
W.popup = nil
ns.MoverCheckDraft()
check("at login, a draft with moves asks to keep them", W.popup == "XAYAUI_MOVER_DRAFT" and CueRulesDB.moverDraft ~= nil, W.popup)
check("  ...with the same two buttons", StaticPopupDialogs.XAYAUI_MOVER_DRAFT and StaticPopupDialogs.XAYAUI_MOVER_DRAFT.button2 == "Cancel moves")
ns.MoverExit("cancel")
check("  ...Cancel moves puts them back and deletes the draft", A.visual.y == 0 and CueRulesDB.moverDraft == nil, A.visual.y)
CueRulesDB.moverDraft = { at = 0, rules = {}, folders = {} }
W.popup = nil
ns.MoverCheckDraft()
check("a draft with no moves is dropped silently", CueRulesDB.moverDraft == nil and W.popup == nil)
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
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
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
