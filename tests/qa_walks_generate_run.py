#!/usr/bin/env python3
"""In-game QA walkthrough for the Generate buttons, the filtered list and Select all (XayaUI_DevAssist 0.7.19, QAWalks-generate.lua; the
feature: XayaUI_Options AutoPicker.lua, on main since 687b624, QA B160). Standing rule V22 (Xaya, 2026-11-07): "make sure every feature or
significant change to the codebase / bug report fixes have an in game qa test walk through with pre-fill confirmation options or data
capturing".
Checks, on the real addons in the stand-in game: the walkthrough is registered with prefill on and every step has a check or is a
question (noVerdict); its checks give the right verdict for what the picker lists after each button is pressed (the buttons' own handlers
are the picker's AP.Load, which the real buttons call): the 4 x (specs + class) buttons with her exact labels and none saying
Auto-populate, a list only after a press, each filter lists its own kind (and a wrong filter or a non-filtered list gets a FAIL: the
negative controls), Select all ticks and unticks the rows shown only, another spec's Aura list (learned auras, or the "Switch to" message),
the class-wide lists, the look step captures widths and asks (no verdict), and the last step leaves nothing ticked or open.
Negative control: QAWalks-generate.lua does not exist on main 7b830cf (the walkthrough is missing there).
Run: python3 tests/qa_walks_generate_run.py   (Lua 5.1 via lupa; slow)."""
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
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS")
local QA = rawget(_G, "XayaUI_DevQA")
local AP = ns and ns.AutoPicker
check("Dev Assist has the QA walkthroughs and the picker is loaded", QA and QA.walks ~= nil and AP ~= nil and AP.Load ~= nil)
if not (QA and AP) then return R end
local w = QA.walks["auto-generate-buttons"]
local okSteps = w ~= nil
for _, st in ipairs(w and w.steps or {}) do if not (type(st.check) == "function" or st.noVerdict) then okSteps = false end end
check("auto-generate-buttons: registered, pre-fill on, every step has a check or is a question", w ~= nil and w.prefill == true and okSteps)
if not w then return R end
-- the same stand-in game as tests/auto_picker_run.py: two specs (577, 581), the Cooldown Manager answering for 581
GetNumSpecializations = function() return 2 end
GetSpecializationInfo = function(i) if i == 1 then return 577, "Havoc", "", 1247264, "DAMAGER" end return 581, "Vengeance", "", 1247263, "TANK" end
GetSpecializationInfoByID = function(id) local n = ({ [577] = "Havoc", [581] = "Vengeance" })[id] or ("Spec " .. tostring(id)); return id, n, "", 136243, "DAMAGER", "DEMONHUNTER", "Demon Hunter" end
ns.rules, ns.folders = {}, {}
ns.CLASS_AURA_DATA = {
  [581] = { entries = { { kind = "cd", id = 187827, name = "Metamorphosis" }, { kind = "cd", id = 204021, name = "Fiery Brand", talent = true }, { kind = "cd", id = 6789, name = "Third" } } },
  [577] = { entries = { { kind = "cd", id = 195072, name = "Fel Rush" }, { kind = "cd", id = 258920, name = "Talent cd", talent = true } } } }
local INFO = {
  [11] = { cooldownID = 11, spellID = 204021, linkedSpellIDs = { 207771 }, hasAura = true, selfAura = false, category = 0 },
  [12] = { cooldownID = 12, spellID = 187827, linkedSpellIDs = {}, hasAura = true, selfAura = true, category = 2 },
  [13] = { cooldownID = 13, spellID = 204596, linkedSpellIDs = {}, hasAura = true, selfAura = false, category = 3 },
  [15] = { cooldownID = 15, spellID = 203720, linkedSpellIDs = { 203819 }, hasAura = true, selfAura = true, category = 2 } }
C_CooldownViewer = {
  GetCooldownViewerCategorySet = function(cat) if cat == 0 then return { 11 } elseif cat == 2 then return { 12, 15 } elseif cat == 3 then return { 13, 11 } end return {} end,
  GetCooldownViewerCooldownInfo = function(id) return INFO[id] end,
  IsCooldownViewerAvailable = function() return true, "" end }
IsPlayerSpell = function(id) return id ~= 204021 and id ~= 258920 end
local SPEC = ns.CurrentSpecID()
check("stand-in spec is Vengeance (581)", SPEC == 581)
check("the picker is published for Dev Assist as ns.OptionsApi.AutoPicker (the harness allows no other cross-addon read)", ns.OptionsApi and ns.OptionsApi.AutoPicker == AP)

-- a real click on a Generate button calls AP.Load and then redraws the window; the stand-in does both
local function redraw() local r = LibStub("AceConfigRegistry-3.0"); r:NotifyChange("CueRules"); W.tick(0.2, 4) end
local function step(i, setup)
  local st = w.steps[i]
  if not st then return false, "no step " .. i end
  if setup and st.setup then st.setup(); W.tick(0.2, 4) end
  local ok, a, b = pcall(st.check)
  if not ok then return false, "error: " .. tostring(a) end
  return a, b
end
local function verdict(name, i, want, setup)
  local v, note = step(i, setup)
  check(name .. "  (" .. tostring(note) .. ")", (v and true or false) == want, note)
end

-- 1. the buttons and no list
AP.Load(SPEC, "cd")   -- a list left open from before
verdict("step 1: with a list open (not closed yet) the check refuses", 1, false, false)
verdict("step 1: Do it for me closes the list; 4 buttons per spec + 4 for the class, her exact wording, none says Auto-populate", 1, true, true)
check("  ...and nothing is listed", AP.view == nil)
-- negative control: a button that still reads "Auto-populate" must fail the check (rename one and look again)
do
  local found
  for _, b in ipairs((function() local out = {} local function walk(x, d) if not x or d > 30 then return end if x.type == "Button" and x.text and x.text.GetText then out[#out + 1] = x end for _, c in ipairs(x.children or {}) do walk(c, d + 1) end end
    local a = LibStub("AceConfigDialog-3.0"); walk(a.OpenFrames["CueRules"], 0); return out end)()) do
    if (b.text:GetText() or ""):find("Generate All Rules for Havoc", 1, true) then found = b; b.text:SetText("Auto-populate Havoc") end
  end
  check("  negative control: a stand-in button renamed to Auto-populate is found", found ~= nil)
  verdict("step 1: a button reading Auto-populate FAILS the check", 1, false, false)
  if found then found.text:SetText("Generate All Rules for Havoc") end
end

-- 2-5: press each button (the handler is the picker's own AP.Load), then Check
AP.Load(SPEC, "cd");     verdict("step 2: CD Tracking lists only cooldowns", 2, true)
AP.Load(SPEC, "aura");   verdict("  negative control: the Aura list does NOT pass the CD step", 2, false)
AP.Load(SPEC, "all");    verdict("  negative control: the All list does NOT pass the CD step", 2, false)
AP.Close();              verdict("  negative control: no list at all does NOT pass the CD step", 2, false)
AP.Load(SPEC, "aura");   verdict("step 3: Aura Tracking lists only auras", 3, true)
AP.Load(SPEC, "debuff"); verdict("step 4: Target Debuff Tracking lists only debuffs", 4, true)
AP.Load(SPEC, "cd");     verdict("  negative control: the CD list does NOT pass the Debuff step", 4, false)
AP.Load(SPEC, "all");    verdict("step 5: All lists the three kinds (3 / 2 / 2 here)", 5, true)

-- 6-8: Select all
verdict("step 6: Select all not ticked yet -> FAIL", 6, false)
AP.TickAll(AP.view.rows, true); redraw()
verdict("step 6: Select all ticked, every row ticked", 6, true)
AP.TickAll(AP.view.rows, false)
verdict("step 7: unticked, every row unticked", 7, true)
AP.TickAll(AP.view.rows, true)
verdict("  negative control: step 7 FAILS while rows are still ticked", 7, false)
AP.TickAll(AP.view.rows, false)
AP.Load(SPEC, "aura"); AP.TickAll(AP.view.rows, true)
verdict("step 8: Aura list, Select all ticked, the cooldowns and debuffs stayed unticked", 8, true)
AP.Load(SPEC, "all"); for _, c in ipairs(AP.view.rows) do if c.kind == "cd" then AP.SetChoice(c, "on", true) end end
AP.Load(SPEC, "aura")
verdict("  negative control: step 8 FAILS when a cooldown not shown is ticked too", 8, false)
for _, c in ipairs(AP.BuildRows(SPEC, "all")) do AP.SetChoice(c, "on", nil) end

-- 9: another spec's Aura button
AP.Load(577, "aura")
verdict("step 9: another spec, nothing learned: no rows and the Switch to Havoc message", 9, true)
table.insert(ns.CLASS_AURA_DATA[577].entries, { kind = "aura", id = 162264, name = "Metamorphosis" })
AP.Load(577, "aura")
verdict("step 9: another spec with a learned aura: the aura is listed", 9, true)
AP.Load(SPEC, "aura")
verdict("  negative control: step 9 FAILS on your own spec's list", 9, false)

-- 10: the class buttons
AP.Load("all", "all"); AP.Load("all", "cd")
verdict("step 10: class CD list, cooldowns from both specs", 10, true)
AP.Load("all", "aura")
verdict("  negative control: step 10 FAILS on the class Aura list", 10, false)

-- 11: the question step captures the widths and gives no verdict
local st11 = w.steps[11]
check("step 11 is a question (noVerdict), so no Accept is offered", st11 and st11.noVerdict == true)
local ok11, _, note11 = pcall(st11.check)
check("  ...its check captures the button widths into the note (" .. tostring(note11 or ""):sub(1, 60) .. ")", ok11 and type(note11) == "string" and note11:find("window", 1, true) ~= nil)

-- 12: the last step puts everything back
AP.Load(SPEC, "all"); AP.TickAll(AP.view.rows, true)
verdict("step 12: before putting back, a ticked row FAILS the check", 12, false, false)
verdict("step 12: Do it for me closes the list and unticks everything", 12, true, true)
check("  ...really: no list and no ticked row", AP.view == nil and (function() for _, c in ipairs(AP.BuildRows(SPEC, "all")) do if AP.Choice(c) then return false end end return true end)())
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
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
