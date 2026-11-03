# Stub test for Drafts.lua (build 0.5.75): the Drafts page shows what each draft holds (triggers, cues, sound / icon) and compact buttons.
# Run from the repo root: python3 tests/drafts_run.py   Needs: pip install lupa. Stand-in game functions: checks the text and the layout fields, not how it looks.
import os, sys
from lupa import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
ns = { rules = {}, CUE_KIND_LABEL = { sound = "Sound", speech = "Speech", text = "Text", texture = "Texture", icon = "Icon", custom = "Custom" } }
function ns.Ignored(s) return s == nil or s == "" or s == "none" or s == "any" end
function ns.CooldownUsed(r) return r.useCooldown == true or (tonumber(r.spellID) or 0) ~= 0 or not ns.Ignored(r.cdState) end
function ns.BuffUsed(r) return r.useBuff == true or (tonumber(r.buffID) or 0) ~= 0 or not ns.Ignored(r.buffState) end
function ns.TriggerSequence(rule)
  local nx = (type(rule.extra) == "table" and type(rule.extra.list) == "table") and #rule.extra.list or 0
  local seq = {}
  if ns.CooldownUsed(rule) then seq[#seq + 1] = "cd" end
  if ns.BuffUsed(rule) then seq[#seq + 1] = "buff" end
  for i = 1, nx do seq[#seq + 1] = "x" end
  return seq
end
ns.TRIGGER_TYPES = { itemCount = { label = "Item Count", fields = { { key = "itemID", kind = "item" }, { key = "n", kind = "number" } } },
                     spellKnown = { label = "Spell Known", fields = { { key = "spellID", kind = "spell" } } } }
function ns.TriggerIcon(rule) return 132345, "the cooldown spell" end
function ns.SoundLabel(s) if not s or s.value == "" then return "(none)" end; if s.source == "kit" then return "[Game] RAID_WARNING" end; return s.value end
ns.PageHidden = function() return false end
function ns.Print() end
C_Spell = { GetSpellName = function(id) return ({ [187827] = "Metamorphosis", [1234] = "Spell Name" })[id] end,
            GetSpellTexture = function(id) return 1247263 end }
C_Item = { GetItemNameByID = function(id) return nil end }
time = function() return 1793660000 end
date = function(f, t) return "2026-11-02 22:10" end
function wipe(t) for k in pairs(t) do t[k] = nil end end
CueRulesDB = { ui = {} }
CreateFrame = function() return setmetatable({}, { __index = function() return function() end end }) end
hooksecurefunc = function() end
C_Timer = { After = function() end }
GetTime = function() return 0 end
InCombatLockdown = function() return false end
''')
lua.execute('local fn = assert(loadfile(...)); fn("XayaUI", ns)'.replace("...", repr(os.path.join(ROOT, "XayaUI/Modules.lua")).replace("'", '"')))   # core contract (0.6.0)
lua.execute('local fn = assert(loadfile(...)); fn("XayaUI", ns)'.replace("...", repr(os.path.join(ROOT, "XayaUI_Options/Drafts.lua")).replace("'", '"')))
lua.execute(r'''
local fails, n = 0, 0
local function check(name, cond, extra) n = n + 1; if not cond then fails = fails + 1; print("FAIL: " .. name .. (extra and ("  -> " .. tostring(extra)) or "")) else print("ok:   " .. name) end end
local drafts = {
  { id = "a", uid = "ua", name = "T - Metamorphosis", ts = 1, isNew = false, rules = {
      { name = "T - Metamorphosis", spellID = 187827, cdState = "ready", buffID = 187827, buffState = "present",
        extra = { list = { { type = "itemCount", itemID = 5512, n = 1 }, { type = "mystery" } } } },
      { isCue = true, cueKind = "sound", sound = { enabled = true, source = "kit", value = "8959" }, visual = {} },
      { isCue = true, cueKind = "icon", cueName = "Meta icon", sound = {}, visual = { kind = "spellicon", iconSrc = "auto" } },
      { isCue = true, cueKind = "speech", sound = { source = "tts", value = "Metamorphosis is up" }, visual = {} },
      { isCue = true, cueKind = "text", sound = {}, visual = { text = { enabled = true } } },
      { isCue = true, cueKind = "texture", sound = {}, visual = { kind = "file", tex = "Interface\\AddOns\\XayaUI\\Media\\Graphics\\ring.tga" } },
      { when = { list = {} } },
  } },
  { id = "b", uid = "ub", name = "Unnamed rule", ts = 1, isNew = true, rules = { { name = "" } } },
  { id = "c", uid = "uc", name = "Old rule", ts = 1, rules = { { name = "x", spellID = 1234, cdState = "notReady", sound = { enabled = true, source = "file", value = "hit.ogg" }, visual = { enabled = true, kind = "spellicon", iconSrc = "spell", iconSpell = 187827 } } } },
  { id = "d", uid = "ud", name = "Broken", ts = 1, rules = "oops" },
}
CueRulesDB.drafts = drafts
local page = ns.BuildDraftsPage()
local a = page.args
local function strip(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T[^|]*|t", ""):gsub("  +", " ")) end   -- the inline icon tags are removed, so spaces collapse
for i = 1, 4 do local g = a["d" .. i]; if g then print("--- " .. g.name); for _, k in ipairs({ "head", "trig", "cue" }) do if g.args[k] then print("   " .. k .. ": " .. strip(g.args[k].name)) end end end end

local g1 = a.d1.args
check("draft 1 head says unsaved changes + counts", strip(g1.head.name):find("unsaved changes to a saved rule", 1, true) and strip(g1.head.name):find("4 triggers", 1, true) and strip(g1.head.name):find("5 cues", 1, true) and strip(g1.head.name):find("and 1 condition", 1, true), strip(g1.head.name))
check("trigger line names the cooldown spell and state", strip(g1.trig.name):find("Cooldown: Metamorphosis (187827), ready", 1, true))
check("trigger line names the aura and state", strip(g1.trig.name):find("Aura: Metamorphosis (187827), present", 1, true))
check("trigger line: more than 4 items are counted", strip(g1.trig.name):find("Item Count: item 5512 (5512)", 1, true) == nil and strip(g1.trig.name):find("Item Count: item 5512", 1, true) ~= nil)
check("cue line names the sound", strip(g1.cue.name):find('Sound "[Game] RAID_WARNING"', 1, true))
check("cue line names the icon cue with its own name", strip(g1.cue.name):find("Meta icon = Icon: from the first trigger", 1, true))
check("cue line: five cues, four shown, 'and 1 more'", strip(g1.cue.name):find("and 1 more", 1, true))
check("buttons are small relative widths", g1.restore.width == "relative" and g1.restore.relWidth <= 0.15 and g1.delete.relWidth <= 0.12 and g1.head.relWidth + g1.restore.relWidth + g1.delete.relWidth < 0.97)
check("button labels are short", g1.restore.name == "Restore" and g1.delete.name == "Delete")
check("delete still asks first", g1.delete.confirm == true)
check("draft 2 (new, empty rule) says so and shows 'none'", strip(a.d2.args.head.name):find("new rule, never saved", 1, true) and strip(a.d2.args.trig.name):find("none", 1, true) and strip(a.d2.args.cue.name):find("none", 1, true))
check("draft 3 (old rule, own sound and icon) shows both", strip(a.d3.args.cue.name):find("Sound", 1, true) and strip(a.d3.args.cue.name):find("Icon: Metamorphosis (187827)", 1, true), strip(a.d3.args.cue.name))
check("draft 4 (damaged) does not break the page and keeps its buttons", a.d4 and a.d4.args.restore and a.d4.args.delete)
check("every draft box is still an inline group", a.d1.type == "group" and a.d1.inline == true)
-- ---- 0.5.81: "Prompt for saving and enable drafts" (default off = autosave) ----
local function Cp(o) if type(o) ~= "table" then return o end local t = {} for k, v in pairs(o) do t[k] = Cp(v) end return t end
local tt = 0; GetTime = function() tt = tt + 1; return tt end; unpack = unpack or table.unpack; ns.Copy = Cp; ns.NewUID = function() return "u" .. math.random(1e9) end; ns.MarkDirty = function() end; ns.RefreshVisual = function() end; ns.DropVisual = function() end
CueRulesDB.ui = {}
ns.rules = { { name = "R", uid = "u1", spellID = 1234, cdState = "ready" } }
ns.DraftsOnOpen()
check("setting off by default", ns.DraftsEnabled() == false)
ns.rules[1].spellID = 4321
check("autosave: an edit is never 'unsaved'", ns.DraftDirty(ns.rules[1]) == false)
ns.DraftNew({ name = "fresh", uid = "u2" })
check("autosave: a new rule is not held as a draft", ns.DraftIsNew({ uid = "u2" }) == false)
ns.DraftsOnClose()
check("autosave: closing keeps the edit and stores no draft", ns.rules[1].spellID == 4321 and #CueRulesDB.drafts == 4)
CueRulesDB.ui.promptSave = true
ns.DraftsOnOpen()
ns.DraftsApplySetting()
check("setting on", ns.DraftsEnabled() == true)
check("on: starts from a clean slate", ns.DraftDirty(ns.rules[1]) == false)
ns.rules[1].spellID = 9999
check("on: an edit is unsaved", ns.DraftDirty(ns.rules[1]) == true)
ns.DraftsOnClose()
check("on: closing reverts and stores a draft", ns.rules[1].spellID == 4321 and #CueRulesDB.drafts == 5)
print(n .. " checks, " .. fails .. " failed")
''')
