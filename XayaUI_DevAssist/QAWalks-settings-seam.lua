-------------------------------------------------------------------------------
-- QAWalks-settings-seam.lua (XayaUI_DevAssist 0.7.55): the in-game regression walkthrough for the settings seam of the platform split,
-- phase P2 (docs/plans/PLATFORM-SPLIT-2026-11-07.md section 5 step 1; core 0.6.75, QA H12). Every module now reads and writes its
-- settings through ns.Settings(module) (core Modules.lua section 0b); nothing a player sees may change, and the saved data stays where it was.
-- Standing rule V22 (Xaya 2026-11-07): every step the addon can judge offers its verdict (prefill = true; recorded only on her click).
-- Two parts around a /reload:
--   part 1: one setting of each module is changed (as its settings page would: Settings > UI Options selection style, the buff bars'
--           spacing, QoL > Cursor Trail size, the Chat Panel's scroll speed, Bonus tooltips' item level memory, a Blizzard Reskin
--           value); a profile of every part is exported and imported back over other values; Theme "Reset everything" is undone again;
--   part 2: after the /reload, every changed value is read back, then everything is put back as it was (from part 1's record).
-- Dev Assist's own data in the old store (the ID probe and chat probe captures) has no page: its line counts are captured before and
-- after the /reload and compared. Reaches XayaUI only through core (ns.Settings, ns.LoadOptions, ns.Share, ns.Theme) and
-- ns.OptionsApi.Profile. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local function View(m) local ns = NS(); return ns and ns.Settings and ns.Settings(m) end
local function Prof() local ns = NS(); return ns and ns.LoadOptions and ns.LoadOptions() and ns.OptionsApi and ns.OptionsApi.Profile end

-- the six settings (module, label, read, write); each read goes through that module's own view
local function RskTable()
    local R = View("reskin"); if not R then return nil end
    if type(R.rsk) == "table" then return R.rsk, "bgAlpha", 0.95 end
    if type(R.friendColors) == "table" then return R.friendColors, "on", true end
    return nil
end
local ITEMS = {
    { key = "platform", label = "Settings > UI Options selection style",
      get = function() local u = View("platform").ui; return u and u.selStyle or "text" end,
      new = function(v) return v == "bar" and "text" or "bar" end,
      set = function(v) local P = View("platform"); P.ui = P.ui or {}; P.ui.selStyle = v end },
    { key = "core", label = "Buff bars: spacing",
      get = function() local g = View("core").barGroup; return g and g.spacing or 0 end,
      new = function(v) return (tonumber(v) or 0) + 1 end,
      set = function(v) local g = View("core").barGroup; if g then g.spacing = v end end },
    { key = "qol", label = "QoL > Cursor Trail: size",
      get = function() local c = View("qol").cursorTrail; return c and c.size or 18 end,
      new = function(v) return (tonumber(v) or 18) + 1 end,
      set = function(v) local Q = View("qol"); Q.cursorTrail = Q.cursorTrail or {}; Q.cursorTrail.size = v end },
    { key = "chat", label = "Chat Panel: scroll speed",
      get = function() local c = View("chat").chat2; return c and c.scrollSpeed or 6 end,
      new = function(v) return (tonumber(v) or 6) + 1 end,
      set = function(v) local C = View("chat"); C.chat2 = C.chat2 or {}; C.chat2.scrollSpeed = v end },
    { key = "bonus", label = "Bonus tooltips: item level memory (seconds)",
      get = function() local t = View("bonus").tooltips; return t and t.ilvl and t.ilvl.cacheSecs or 120 end,
      new = function(v) return (tonumber(v) or 120) + 1 end,
      set = function(v) local B = View("bonus"); B.tooltips = B.tooltips or {}; B.tooltips.ilvl = B.tooltips.ilvl or {}; B.tooltips.ilvl.cacheSecs = v end },
    { key = "reskin", label = "Blizzard Reskin: window opacity (or friend colours on / off)",
      get = function() local t, k, d = RskTable(); if not t then return "none" end; local v = t[k]; if v == nil then v = d end; return v end,
      new = function(v) if v == "none" then return "none" end; if type(v) == "boolean" then return not v end; return (tonumber(v) or 0.95) >= 0.99 and 0.9 or 1 end,
      set = function(v) local t, k = RskTable(); if t and v ~= "none" then t[k] = v end end },
}
local function Enc(v) return type(v) == "boolean" and (v and "true" or "false") or tostring(v) end
local function Dec(s) if s == "true" then return true elseif s == "false" then return false end; return tonumber(s) or s end
local function Line(tag, vals) local t = {}; for _, it in ipairs(ITEMS) do t[#t + 1] = it.key .. "=" .. Enc(vals[it.key]) end; return tag .. ": " .. table.concat(t, " ") end
local function Parse(note, tag)
    local seg = note and note:match(tag .. ": ([^|]*)")
    if not seg then return nil end
    local out = {}
    for k, v in seg:gmatch("(%w+)=(%S+)") do out[k] = Dec(v) end
    return out
end
local function Same(a, b) if type(a) == "number" and type(b) == "number" then return math.abs(a - b) < 0.001 end; return a == b end
local function DevCounts()
    local D = View("devassist"); if not D then return "none" end
    local function n(t) return type(t) == "table" and #t or 0 end
    local cp = D.chatProbe
    return ("idProbe %d, idProbeStream %d, chatProbe %d"):format(n(D.idProbe), n(D.idProbeStream), cp and n(cp.lines) or 0)
end

local st = {}
local changed   -- set in part 1 of this session (gone after the /reload)
QA.Register("settings-seam", { title = "Settings seam: every module's settings after a change, a profile import and Reset (part 1 of 2) (H12)", area = "Platform", qa = "H12", order = 272.2, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: one setting of each module is changed, as its settings page would change it: Settings > UI Options selection style, the buff bars' spacing, QoL > Cursor Trail size, the Chat Panel's scroll speed, Bonus tooltips' item level memory, and a Blizzard Reskin value (window opacity, or friend colours when only those are set up). What each was is kept in this step's record; part 2 puts them back.\n\n|cffffd100Expect:|r the check reads each new value back through that module's settings.",
        setup = function()
            if not View("platform") then error("XayaUI core is too old or off (no ns.Settings)") end
            st.was, st.set = {}, {}
            for _, it in ipairs(ITEMS) do
                local v = it.get(); st.was[it.key] = v
                local nv = it.new(v); it.set(nv); st.set[it.key] = it.get()
            end
            st.dev = DevCounts()
            changed = true
        end,
        check = function()
            if not st.set then return nil, "press Do it for me first" end
            local bad = {}
            for _, it in ipairs(ITEMS) do
                if not Same(it.get(), st.set[it.key]) or (st.set[it.key] ~= "none" and Same(st.set[it.key], st.was[it.key])) then bad[#bad + 1] = it.label end
            end
            local ns = NS()
            if ns and ns.barGroup and not Same(ns.barGroup.spacing, st.set.core) then bad[#bad + 1] = "the bars read another spacing" end
            return #bad == 0, (#bad == 0 and "every module reads its new value" or ("not read back: " .. table.concat(bad, ", "))) .. " | " ..
                Line("set", st.set) .. " | " .. Line("was", st.was) .. " | dev: " .. st.dev
        end },
    { text = "Press |cffffd100Do it for me|r: a profile with every part is made from these values, the six values are then set back to what they were, and the profile is imported with every part but Rules ticked (the buff bars' spacing travels with Rules, so it is left out of this check).\n\n|cffffd100Expect:|r a Reload / Later prompt (press |cffffd100Later|r); the check reads every imported value in its module.",
        setup = function()
            local ns, P = NS(), Prof()
            if not (ns and P and ns.Share) then error("the settings window could not load") end
            if not st.set then error("run step 1 first") end
            local inc = {}
            for _, c in ipairs(P.COMPONENTS) do inc[c.key] = true end
            local txt = ns.Share.Encode("profile", P.Snapshot(inc, "qa settings seam"))
            for _, it in ipairs(ITEMS) do if it.key ~= "core" then it.set(st.was[it.key]) end end
            inc.rules = nil
            local data, def = ns.Share.Read(txt or "")
            st.imp = data and def and def.Apply(data, { inc = inc, rules = "add" }) and true or false
        end,
        check = function()
            if st.imp == nil then return nil, "press Do it for me first" end
            local bad, got = {}, {}
            for _, it in ipairs(ITEMS) do
                got[it.key] = it.get()
                if it.key ~= "core" and not Same(got[it.key], st.set[it.key]) then bad[#bad + 1] = it.label end
            end
            return #bad == 0, (#bad == 0 and "every module's page reads the imported value" or ("not imported: " .. table.concat(bad, ", "))) .. " | " .. Line("now", got)
        end },
    { text = "Press |cffffd100Do it for me|r: your theme is kept, Settings > Theme > |cffffd100Reset everything|r is pressed, the result is read, and your theme is put straight back.\n\n|cffffd100Expect:|r the windows flash to the class theme and back. The check reads that the reset reached the theme every module's pages use.",
        setup = function()
            local ns = NS(); local T = ns and ns.Theme
            if not (T and T.ResetAll and T.Export and T.Import) then error("XayaUI's theme is not loaded") end
            local saved = T.Export()
            local th0 = View("platform").theme
            local before = { size = th0 and th0.size, base = th0 and th0.base }
            T.ResetAll()
            local th = View("platform").theme
            st.reset = { size = th and th.size, base = th and th.base, tokens = th and type(th.tokens) == "table" and next(th.tokens) == nil }
            T.Import(saved, nil, true)
            local th2 = View("platform").theme
            st.reset.back = th2 and th2.size == before.size and th2.base == before.base and true or false
        end,
        check = function()
            local r = st.reset
            if not r then return nil, "press Do it for me first" end
            local ok = r.size == "M" and r.base == "class" and r.tokens and r.back
            return ok and true or false, ("after Reset everything: size %s, base %s, no colour overrides: %s; your theme back: %s"):format(
                tostring(r.size), tostring(r.base), r.tokens and "yes" or "NO", r.back and "yes" or "NO")
        end },
    { done = true, text = "Press |cffffd100Done|r here first (so this record is kept), type |cffffd100/reload|r, and run \"Settings seam: every module's changed setting after the /reload (part 2 of 2) (H12)\"." },
} })

QA.Register("settings-seam-reload", { title = "Settings seam: every module's changed setting after the /reload (part 2 of 2) (H12)", area = "Platform", qa = "H12", order = 272.3, prefill = true, steps = {
    { text = "Run this after part 1 and its /reload.\n\n|cffffd100Expect:|r every value part 1 set is still there: the selection style, the bars' spacing, the cursor trail size, the Chat Panel's scroll speed, the tooltips' item level memory and the Blizzard Reskin value. Dev Assist's capture counts are the same as before the /reload.",
        check = function()
            if changed then return nil, "not reloaded yet: type /reload, then come back and Check again" end
            local note = QA.SeenNote("settings-seam", 1)
            local set = Parse(note, "set")
            if not set then return nil, "part 1 has no record: run it to its end first (press Done before the /reload)" end
            local bad, got = {}, {}
            for _, it in ipairs(ITEMS) do got[it.key] = it.get(); if not Same(got[it.key], set[it.key]) then bad[#bad + 1] = it.label end end
            local dev0 = note:match("dev: ([^|]*)") or "?"
            local dev = DevCounts()
            if dev0 ~= dev then bad[#bad + 1] = "Dev Assist's captures (" .. dev0 .. " before)" end
            return #bad == 0, (#bad == 0 and "every module kept its setting over the /reload" or ("changed over the /reload: " .. table.concat(bad, ", "))) ..
                " | " .. Line("now", got) .. " | dev: " .. dev
        end },
    { done = true, text = "Last step: press |cffffd100Do it for me|r to put the six settings back as they were before part 1 (from part 1's record). Then press |cffffd100Done|r.",
        setup = function()
            local was = Parse(QA.SeenNote("settings-seam", 1), "was")
            if not was then error("part 1's record is missing: set the six settings back yourself") end
            for _, it in ipairs(ITEMS) do if was[it.key] ~= nil then it.set(was[it.key]) end end
            local ns = NS(); if ns and ns.Fire then ns.Fire("CONFIG_CHANGED") end
        end },
} })
