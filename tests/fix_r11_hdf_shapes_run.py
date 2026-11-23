#!/usr/bin/env python3
"""T14 of the hidden-data fight (round 11b, triage unit; build spec docs/plans/HIDDEN-DATA-FIGHT-SPEC-2026-11-17.md section 5 T14 and
section 6 F1, XUI-Docs). Her answers: SD-127 "Yes, fix it first (Recommended)": any failure under any of the three guessed UNIT_AURA
payload shapes (A, B, C) blocks bundle 1, and F1 (Engine.lua RouteAura) is fixed before landing; SD-126 "Key only, raids in smaller
tests (Recommended)".

What the player sees, inside a Mythic+ key, in combat (auras hidden: the stand-in's restriction state machine, tests/harness/world.lua),
for each payload shape the game might hand (spec 2.2; all INFERENCE, UNVERIFIED IN GAME):
  A  the payload is a hidden value whose real type is table (index, '#' and iterate raise);
  B  a plain table whose every field is hidden (issecrettable true, canaccesstable true);
  C  a forbidden table (canaccesstable false; index, assign and iterate raise "attempted to index a forbidden table", WSV:50);
  U  shape A with a hidden unitTarget too (spec 2.2 plays it as an extra variant: the stand-in keeps unitTarget readable by default).
Per variant, one fresh stand-in session (XayaUI, XayaUI_Rules, XayaUI_Options; the line hook on, as in every unit test):
  1. a NeverSecret buff (W.auraSecrecy 0: the spell-ID read answers in combat, PRED:27-31) is gained: its display shows on the next
     frames, and the engine (Engine.lua) raised no Lua error and recorded nothing (CueRulesDB.errorLog, SD-139);
  2. ... its rule was re-checked (the engine's player aura route ran: Engine.lua RouteAura -> pend.aura);
  3. ... the buff falls off: the display hides again (the rules are not left stale);
  4. a debuff of yours lands on the target (the target / focus route, tgtFrame): its check reads your debuffs on the target again, with
     no Lua error (its answer stays unknown in the key, spec F7, so the rule itself is not re-checked in full: the engine's design);
  5. the whole play: no Lua error from any handler of the event (AuraAlias.lua's OnAura included), nothing in the error record, and no
     line-hook finding in any XayaUI file.
Before the triage unit's F1 fix (r11bpre-triage) shape C fails 1-5: RouteAura reads info.isFullUpdate, the forbidden table raises, the
handler stops before pend.aura / Kick, so the display stays as it was (stale rules) and the error reaches the record (an error popup in
game). Shapes A and B pass on the old code too (they route "re-check everything", the round 6 design); the test keeps them so a change
that breaks them is caught. Variant U: see section 6 F1 of the triage report (the hidden unitTarget handling).
Stand-in numbers and texts are not WoW; the payload shapes and a hidden unitTarget are INFERENCE (spec 2.2, open question 6).
Run: python3 tests/fix_r11_hdf_shapes_run.py   (Lua 5.1 via lupa; XUI_API_INDEX for the API index)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L, VARIANT)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { "[" .. VARIANT .. "] " .. name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local S = W.S
local SHAPE = (VARIANT == "U") and "A" or VARIANT
-- the target exists (the stand-in's world has the player only); the test's own model of who is targeted
local targetOn = false
local UE0 = UnitExists
UnitExists = function(u) if u == "target" then return targetOn end return UE0(u) end
local UG0 = UnitGUID
UnitGUID = function(u) if u == "target" and targetOn then return "Creature-0-0-0-0-1-0000000001" end return UG0(u) end
-- (4) reads of your debuffs on the target (Triggers.lua TDList reads C_UnitAuras.GetUnitAuras): counted, so the target route is seen to run
-- even while its answer stays unknown in the key (the engine re-checks a rule in full only when a check's answer changed, Engine.lua)
local tgtReads = 0
local GUA0 = C_UnitAuras.GetUnitAuras
C_UnitAuras.GetUnitAuras = function(unit, ...) if unit == "target" then tgtReads = tgtReads + 1 end; return GUA0(unit, ...) end
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
if not ns then check("(sanity) core loaded", false); return R end
W.auraSecrecy = W.auraSecrecy or {}
W.auraSecrecy[8070] = 0         -- NeverSecret: the spell-ID read answers in combat (PRED:27-31)
ns.rules = {}
local function mk(nm, f)
  local r = ns.NewRule(); r.name = nm; r.enabled = true
  r.visual.enabled, r.visual.kind, r.visual.w, r.visual.h = true, "spellicon", 32, 32
  r.visual.trigger = "condition"; r.sound.enabled = false
  f(r); ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r; return r
end
local NEVER = mk("never secret buff", function(r) r.useBuff, r.buffID, r.buffState, r.cdState = true, 8070, "present", "none"; r.visual.trigger = "buffActive" end)
local TGT = mk("my target debuff", function(r) r.cdState, r.buffState = "none", "none"; r.extra = { list = { { type = "targetDebuff", spellID = 350001, unit = "target", state = "yes" } } } end)
ns.MarkDirty()
W.tick(1 / 60, 30)
local evals = {}
local E0 = ns.Evaluate
ns.Evaluate = function(r, ...) evals[r] = (evals[r] or 0) + 1; return E0(r, ...) end
local framesOf = ns.VisualProbeState and ns.VisualProbeState()
local function shown(r) local fr = framesOf and framesOf[r]; return fr and fr:IsShown() and true or false end
local function frame(n) W.tick(1 / 60, n or 1) end
local function log() return type(CueRulesDB.errorLog) == "table" and CueRulesDB.errorLog or {} end
local function logSum() local n = 0; for _, e in ipairs(log()) do n = n + (e.n or 1) end; return n end
local function logDump() local t = {}; for _, e in ipairs(log()) do t[#t + 1] = tostring(e.code) .. " x" .. tostring(e.n) .. " " .. tostring(e.msg):sub(1, 160) end; return table.concat(t, " || ") end
local function xuiFindings()
  local n, t = 0, {}
  for _, s in ipairs((L.lineHook and L.lineHook.sites) or {}) do
    if tostring(s.site):find("^XayaUI") then n = n + (s.n or 1); t[#t + 1] = tostring(s.rule) .. " " .. tostring(s.site) end
  end
  return n, table.concat(t, ", ")
end
local function errs(from) local t = {}; for i = from + 1, #W.errors do t[#t + 1] = tostring(W.errors[i]):sub(1, 200) end; return t end
-- the engine's own share (checks 1-4 judge the engine's routes; check 5 judges every handler of the event, AuraAlias.lua's included)
local function engineErrs(from) local t = {}; for i = from + 1, #W.errors do local x = tostring(W.errors[i]); if x:find("XayaUI_Rules/Engine.lua", 1, true) then t[#t + 1] = x:sub(1, 200) end end; return t end
local function engineLog() local n = 0; for _, e in ipairs(log()) do if tostring(e.msg):find("XayaUI_Rules/Engine.lua", 1, true) then n = n + (e.n or 1) end end; return n end
check("(sanity) the NeverSecret buff's display is hidden before the key", not shown(NEVER))
-- into the key, in combat: auras hidden (Combat and ChallengeMode Active)
W.enterInstance("party", 8); W.startKey(503, 10, { 9, 10 }); frame(10)
W.enterCombat(); frame(10)
check("(sanity) in the key, in combat: auras are hidden (C_Secrets.ShouldAurasBeSecret)", C_Secrets.ShouldAurasBeSecret() == true and W.aurasSecret())
W.payloadShape = SHAPE
-- the payload as the game would hand it; variant U also hands a hidden unitTarget (the stand-in fires UNIT_AURA itself)
local function fireAura(unit, info)
  local p = W.payload(info)
  if VARIANT == "U" then W.fire("UNIT_AURA", S.new(unit), p) else W.fire("UNIT_AURA", unit, p) end
end
local e0, l0, le0 = #W.errors, logSum(), engineLog()
for k in pairs(evals) do evals[k] = nil end
local a = W.addAura("player", { spellId = 8070, duration = 30 }, true)
fireAura("player", { addedAuras = { { spellId = 8070, auraInstanceID = a.auraInstanceID } } })
frame(6)
local shape = S.shape and S.shape(W.payload({ isFullUpdate = true })) or "?"
check("(sanity) the payload handed is shape " .. SHAPE, shape == SHAPE or (SHAPE == "B" and shape ~= "A" and shape ~= "C"), shape)
check("1. a NeverSecret buff gained in combat in a key: its display shows (shape " .. SHAPE .. ")", shown(NEVER), shown(NEVER))
check("1. ... the engine raised no Lua error and recorded nothing", #engineErrs(e0) == 0 and engineLog() == le0, table.concat(engineErrs(e0), " | ") .. " || " .. logDump())
check("2. ... its rule was re-checked (the player aura route ran)", (evals[NEVER] or 0) >= 1, evals[NEVER])
e0, l0, le0 = #W.errors, logSum(), engineLog()
W.removeAura("player", a.auraInstanceID, true)
fireAura("player", { removedAuraInstanceIDs = { a.auraInstanceID } })
frame(6)
check("3. ... the buff falls off: its display hides (the rules are not left stale)", not shown(NEVER), shown(NEVER))
check("3. ... the engine raised no Lua error and recorded nothing", #engineErrs(e0) == 0 and engineLog() == le0, table.concat(engineErrs(e0), " | ") .. " || " .. logDump())
-- the target / focus route
targetOn = true; W.fire("PLAYER_TARGET_CHANGED"); frame(6)
e0, l0, le0 = #W.errors, logSum(), engineLog()
local r0 = tgtReads
local d = W.addAura("target", { spellId = 350001, duration = 12, isHelpful = false }, true)
fireAura("target", { addedAuras = { { spellId = 350001, auraInstanceID = d.auraInstanceID } } })
frame(6)
check("4. a debuff of yours lands on the target: the target route ran (its check read your debuffs on the target again)", tgtReads > r0, tgtReads - r0)
check("4. ... the engine raised no Lua error and recorded nothing", #engineErrs(e0) == 0 and engineLog() == le0, table.concat(engineErrs(e0), " | ") .. " || " .. logDump())
local nf, lf = xuiFindings()
check("5. no Lua error anywhere in the play, nothing in the error record, and no line-hook finding in any XayaUI file (Engine.lua,"
  .. " AuraAlias.lua and every other UNIT_AURA handler)", #W.errors == 0 and #log() == 0 and nf == 0, #W.errors .. " errors: "
  .. table.concat(errs(0), " | ") .. "; record: " .. logDump() .. "; findings: " .. lf)
W.leaveCombat(); frame(10); W.completeKey(); W.leaveInstance(); frame(10)
return R
end
'''


def run_variant(variant):
    folders = {k: v for k, v in H.find_addons().items() if k in ("XayaUI", "XayaUI_Rules", "XayaUI_Options")}
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": {}}))
    res = L.eval("function(src, W, Ld, v) return loadstring(src)()(W, Ld, v) end")(LUA, world, loader, variant)
    out = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    return out, errs


def main():
    only = os.environ.get("XUI_HDF_VARIANTS")
    variants = [v for v in ("A", "B", "C", "U") if not only or v in only]
    total = bad = nerr = 0
    for v in variants:
        out, errs = run_variant(v)
        for name, ok in out:
            print(("PASS " if ok else "FAIL ") + name)
            total += 1
            bad += 0 if ok else 1
        for e in errs:
            print("ERROR in the game stand-in [%s]: %s" % (v, e[:600]))
            nerr += 1
    if only:
        print("(variants run: %s; XUI_HDF_VARIANTS set: a partial run is not a pass)" % ",".join(variants))
        bad += 1
    print("%d checks, %d failed, %d Lua errors" % (total, bad, nerr))
    sys.exit(1 if bad or nerr else 0)


if __name__ == "__main__":
    main()
