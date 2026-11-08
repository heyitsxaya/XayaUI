-------------------------------------------------------------------------------
-- TriggersEditor.lua : the Trigger tab of the rule editor (part of the settings window, XayaUI_Options; 0.6.0).
-- Moved out of Triggers.lua, which keeps the trigger types themselves and how they are read in game. This file only builds the
-- option rows: names, numbered headers, dividers, Move up / Move down, and the rows of every extra trigger type.
-- Called from Options.lua BuildRule; H = ns.UI (the shared option builders). Own code. UNTESTED in game.
-------------------------------------------------------------------------------
-- (P4b, XayaUI_Rules_Options 0.6.77) Moved unchanged from XayaUI_Options/RuleEditor/ into the rule editor's own load-on-demand addon,
-- loaded by the settings window when it opens while XayaUI Rules is on; with XayaUI Rules off none of its files is read.
local _, ns = ...
ns = _G.XayaUI_NS or ns
local S = ns.TriggerShared
if not S then return end   -- (Options 0.6.84, P4) XayaUI Rules is switched off: no rule editor is built, so this file defines nothing
local Call, MAX_ROWS, ORDER, TYPES = S.Call, S.MAX_ROWS, S.ORDER, S.TYPES
local unpack = unpack or table.unpack

function ns.TriggerNameArg(rule, tok, j, order, onChange)
    return { type = "input", order = order, width = "full", name = "Name  (optional: shown in grey under the trigger number)",
        desc = "Names this trigger, up to 30 characters. The name shows under the trigger number and in dropdowns.",
        get = function() return ns.TriggerName(rule, tok, j) or "" end,
        set = function(_, v)
            v = tostring(v or ""):gsub("[%c|]", ""):sub(1, 30)
            if v:match("^%s*$") then v = nil end
            if tok == "cd" then rule.cdName = v elseif tok == "buff" then rule.buffName = v
            else local t = rule.extra.list[j]; if t then t.name = v end end
            onChange()
        end }
end
local GLYPH_OPEN = "|TInterface\\Buttons\\Arrow-Down-Up:16:16|t"
local GLYPH_CLOSED = "|TInterface\\ChatFrame\\ChatFrameExpandArrow:16:16|t"
-- Trigger pane header = the same header a cue or condition has: open / close button + "Trigger 1:  Cooldown", and the optional name
-- typed in the gray "name (optional)" box under it (arg.xuiEdit, drawn by Skin.lua). The pane body is indented.
-- 0.6.2: the open / close button is a real button at the left (arg.xuiChevron, drawn by Skin.lua) instead of an arrow inside the
-- title text: the text arrow sat in a margin the scroll area cuts off, so it never showed. The row itself no longer reacts to the mouse.
function ns.TriggerPaneHeader(pane, rule, tok, j, title, onChange)
    local hdr = pane.args.hdr
    local a = hdr.arg
    local isOpen = a.xuiChevron
    pane.arg = { xuiIndent = ns.BODY_INDENT or 20 }
    a.xuiHeadOut = ns.BODY_INDENT or 20
    a.xuiChevron = isOpen or function() return true end
    hdr.name = function()
        if ns.SkinRows and ns.SkinRows() then return title end
        return ((not isOpen or isOpen()) and GLYPH_OPEN or GLYPH_CLOSED) .. "  " .. title
    end
    local nameArg = ns.TriggerNameArg(rule, tok, j, 0, onChange)
    a.xuiEdit = {
        title = function() return title end,
        get = function() return nameArg.get() end,
        set = function(v) nameArg.set(nil, v) end,
        hint = function() return ns.TriggerLightText(rule, tok, j) end,   -- TRUE / FALSE / UNKNOWN right now, to the right of the title
    }
    a.xuiSub = function() return " " end   -- makes room for the name box under the title
end
-- A ruled line with a blank gap above and below, placed just before trigger number `pos` (not before the first) so that several
-- triggers read as separate blocks. Each trigger's own options sit at pos*100 .. pos*100+99, so pos*100-3..-1 is free.
function ns.TriggerDivider(args, key, pos, hiddenFn)
    if not pos or pos <= 1 then return end
    local function mk(t) t.hidden = hiddenFn; return t end
    args[key .. "SpA"] = mk({ type = "description", order = pos * 100 - 3, width = "full", fontSize = "small", name = " " })
    args[key]          = mk({ type = "header", order = pos * 100 - 2, name = "" })
    args[key .. "SpB"] = mk({ type = "description", order = pos * 100 - 1, width = "full", fontSize = "small", name = " " })
end
-- Number, order and Move up / Move down for the two built-in triggers (their options are defined in Options.lua).
function ns.DecorateBuiltinTriggers(rule, args)
    local P = ns.TriggerPositions(rule)
    local function changed() ns.UI.Changed(rule); ns.UI.Notify() end
    local function setup(tok, label, keys, removeKey, used)
        local pos = P[tok]
        if not pos then return end
        for _, k in ipairs(keys) do
            local o = args[k]
            if o then o.order = pos * 100 + (tonumber(o.order) or 0) end
        end
        local title = ns.TriggerHeader(rule, tok, nil, pos, label)
        local nameKey = tok .. "Rename"
        args[nameKey] = ns.TriggerNameArg(rule, tok, nil, 0.5, changed)
        local skinned = ns.SkinRows and ns.SkinRows()
        if not (ns.GatePane and skinned) then   -- skin off: keep the old numbered header with the text buttons and the Name box
            keys = { unpack(keys) }; keys[#keys + 1] = nameKey
            args[nameKey].order = pos * 100 + 0.5
            args[keys[1]].name = pos .. ".  " .. label
            return
        end
        args[nameKey] = nil   -- skin on: the name is typed in the header itself (ns.TriggerPaneHeader)
        local rm = args[removeKey]
        local removeFn = rm and rm.func
        if rm then rm.hidden = true end              -- the red X in the row header replaces the Remove button
        if args[keys[1]] then args[keys[1]].hidden = true end   -- the row header already carries the title
        ns.GatePane(rule, args, "trig_" .. tok, title, pos * 100, function() return used(rule) end, keys)
        ns.TriggerDivider(args, "div_" .. tok, pos, function() return not used(rule) end)
        local pane = args["pane_trig_" .. tok]
        ns.TriggerPaneHeader(pane, rule, tok, nil, title, changed)
        pane.args.hdr.arg.xuiActions = function()
            return {
                up = (pos > 1) and function() ns.MoveTrigger(rule, pos, -1); changed() end or false,
                down = (pos < #P.seq) and function() ns.MoveTrigger(rule, pos, 1); changed() end or false,
                copy = (tok == "cd" or tok == "buff") and function()
                    local X = rule.extra
                    if #X.list >= 12 then ns.Print("a rule can hold at most 12 additional triggers"); return end
                    local t
                    if tok == "cd" then
                        t = { type = "cooldown", spellID = tonumber(rule.spellID) or 0, state = (rule.cdState and not ns.Ignored(rule.cdState)) and rule.cdState or "ready", maxCharges = tonumber(rule.maxCharges) or 0 }
                    else   -- Buff / Aura: the copy is a further Buff / Aura row with the same aura IDs, state, and seconds left (0.6.4: extras are kept)
                        t = { type = "buffAura", spellID = tonumber(rule.buffID) or 0, state = (rule.buffState == "missing") and "no" or "yes",
                            alt = (type(rule.buffAlt) == "table" and #rule.buffAlt > 0) and ns.Copy(rule.buffAlt) or nil,
                            timeOp = rule.buffTimeOp, timeSec = rule.buffTimeSec }
                    end
                    local sq = ns.TriggerSequence(rule)
                    local at, jx = #sq + 1, 0
                    for i, tk in ipairs(sq) do if tk == tok then at = i + 1 end end
                    for i = 1, at - 1 do if sq[i] == "x" then jx = jx + 1 end end
                    table.insert(X.list, jx + 1, t)
                    table.insert(sq, at, "x")
                    rule.trigOrder = sq
                    if ns.RemapOutcomeRefs then ns.RemapOutcomeRefs(rule, function(n) if n > jx then return "x" .. (n + 1) end return "x" .. n end) end
                    changed()
                end or nil,
                del = removeFn,
            }
        end
    end
    -- "readable in combat?" line under each built-in trigger (ns.TriggerCombatNote)
    local function CombatLine(tok, order, used)
        return { type = "description", order = order, width = "full", fontSize = "small",
            hidden = function() if not used(rule) then return true end; local okc, n = pcall(ns.TriggerCombatNote, rule, tok); return not (okc and n) end,
            name = function() local okc, n = pcall(ns.TriggerCombatNote, rule, tok); return okc and n or "" end }
    end
    if ns.TriggerCombatNote then
        args.cdCombat = CombatLine("cd", 6.6, ns.CooldownUsed)
        args.buffCombat = CombatLine("buff", 13.6, ns.BuffUsed)
    end
    -- the whole rule in one line, above every trigger (#21 part 1)
    if ns.RuleCombatSummary then
        args.ruleCombat = { type = "description", order = 0.05, width = "full", fontSize = "medium",
            hidden = function() local ok, n = pcall(ns.RuleCombatSummary, rule); return not (ok and n) end,
            name = function() local ok, n = pcall(ns.RuleCombatSummary, rule); return ok and n or "" end }
    end
    setup("cd", "Cooldown", { "cdHeader", "spellID", "spellName", "spellSearch", "spellPick", "cdState", "maxCharges", "detected", "cdCombat", "cdRemove" }, "cdRemove", ns.CooldownUsed)
    setup("buff", "Buff / Aura", { "buffHeader", "buffState", "buffTimeOp", "buffTimeSec", "buffSearch", "buffID", "buffName", "buffAltSearch", "buffAlt", "buffAltNames", "buffCombat", "buffRemove" }, "buffRemove", ns.BuffUsed)
end

-------------------------------------------------------------------------------
-- Options UI. Called from Options.lua BuildRule; H = ns.UI (the shared option builders).
-------------------------------------------------------------------------------
local function ItemName(id)
    id = tonumber(id) or 0
    if id == 0 then return "" end
    local n = Call(C_Item and C_Item.GetItemNameByID, id)
    if n then return n end
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    return "|cffaaaaaa(item name not loaded yet - reopen this tab)|r"
end

-- An ID typed into a box: a number is stored, an empty box clears it (0), anything else keeps the old value (audit D45: "1o" stored 0).
local function SetID(t, k, v, onN, refresh)
    v = tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local n = (v == "") and 0 or tonumber(v)
    if n == nil then ns.Print("'" .. v .. "' is not a number: the ID is unchanged"); if refresh then refresh() end; return end
    t[k] = n; onN()
end

local function FieldArgs(rule, t, f, H, order, row)
    local k = f.key
    local on = function() H.Changed(rule) end
    local onN = function() H.Changed(rule); H.Notify() end
    if f.kind == "spell" then
        row[k .. "Search"] = H.SearchBox(order, function(id) t[k] = id; onN() end, nil, f.search or "cd")   -- search first, then the ID it fills in, then the spell's name
        row[k .. "ID"] = { type = "input", name = f.label, order = order + 0.1, width = "half",
            get = function() return tostring(t[k] or 0) end,
            set = function(_, v) SetID(t, k, v, onN, H.Notify) end }
        row[k .. "Name"] = { type = "description", order = order + 0.2, width = "double", fontSize = "medium",
            name = function() return H.SpellName(t[k]) end }
    elseif f.kind == "talent" then
        row[k .. "Search"] = H.SearchBox(order, function(id) t[k] = id; onN() end, nil, "talent")
        row[k .. "ID"] = { type = "input", name = f.label, order = order + 0.1, width = "half",
            get = function() return tostring(t[k] or 0) end,
            set = function(_, v) SetID(t, k, v, onN, H.Notify) end }
        row[k .. "Name"] = { type = "description", order = order + 0.2, width = "double", fontSize = "medium",
            name = function() return H.SpellName(t[k]) end }
        local function Build()
            local values, sorting = {}, {}
            for _, tl in ipairs(ns.BuildTalentList and ns.BuildTalentList() or {}) do
                local key = tostring(tl.id)
                local icon = Call(C_Spell and C_Spell.GetSpellTexture, tl.id) or 134400
                values[key] = "|T" .. tostring(icon) .. ":16|t " .. tl.name .. (tl.choice and "  (choice node)" or "") .. "  [" .. tl.id .. "]"
                sorting[#sorting + 1] = key
            end
            return values, sorting
        end
        row[k .. "Pick"] = { type = "select", name = "Or pick from your current build", order = order + 0.3, width = "double",
            values = function() local v = Build(); return v end,
            sorting = function() local _, s = Build(); return s end,
            get = function()
                local key = tostring(t[k] or 0)
                local v = Build()
                if v[key] then return key end
            end,
            set = function(_, v) t[k] = tonumber(v) or 0; onN() end }
    elseif f.kind == "item" then
        row[k .. "ID"] = { type = "input", name = f.label, order = order, width = "half",
            get = function() return tostring(t[k] or 0) end,
            set = function(_, v) SetID(t, k, v, onN, H.Notify) end }
        row[k .. "Name"] = { type = "description", order = order + 0.1, width = "double", fontSize = "medium",
            name = function() return ItemName(t[k]) end }
        row[k .. "Search"] = H.SearchBox(order + 0.2, function(id) t[k] = id; onN() end, nil, "item")
    elseif f.kind == "select" then
        if f.dyn then
            row[k] = { type = "select", name = f.label, order = order, width = "double",
                values = function() local v = f.dyn(); return v end,
                sorting = function() local _, o = f.dyn(); return o end,
                get = function() return t[k] end, set = function(_, v) t[k] = v; onN() end }
        else
            row[k] = H.Sel(t, k, f.label, order, f.vals.values, f.vals.order, onN, { width = f.width or "double" })
            if f.default ~= nil then row[k].get = function() if t[k] == nil then return f.default end; return t[k] end end
        end
    elseif f.kind == "range" then
        row[k] = H.Rng(t, k, f.label, order, f.min, f.max, f.step, on, { width = "double" })
    elseif f.kind == "number" then
        row[k] = { type = "input", name = f.label, order = order, width = "half",
            get = function() return t[k] ~= nil and tostring(t[k]) or "" end,
            set = function(_, v) t[k] = tonumber(v); on() end }
    elseif f.kind == "toggle" then
        row[k] = H.Tog(t, k, f.label, order, onN, { width = "normal" })
    elseif f.kind == "idlist" then
        -- several IDs in one box (extra aura IDs, ANY of them): search to add one, or type them comma separated
        row[k .. "Search"] = H.SearchBox(order, function(id)
            id = tonumber(id) or 0
            if id == 0 or id == (tonumber(t.spellID) or 0) then return end
            t[k] = type(t[k]) == "table" and t[k] or {}
            for _, x in ipairs(t[k]) do if x == id then return end end
            if #t[k] >= 30 then ns.Print("a trigger can watch at most 30 extra aura IDs"); return end
            t[k][#t[k] + 1] = id; onN()
        end, "Also count these auras: search to add another", f.search or "aura")
        row[k] = { type = "input", name = f.label, order = order + 0.1, width = "full", desc = f.desc,
            get = function() local l = type(t[k]) == "table" and t[k] or {}; local o = {}; for i, v in ipairs(l) do o[i] = tostring(v) end; return table.concat(o, ", ") end,
            set = function(_, v)
                local out, seen = {}, { [tonumber(t.spellID) or 0] = true }
                for n in tostring(v or ""):gmatch("%d+") do
                    local id = tonumber(n)
                    if id and id > 0 and not seen[id] and #out < 30 then seen[id] = true; out[#out + 1] = id end
                end
                t[k] = (#out > 0) and out or nil
                onN()
            end }
        row[k .. "Names"] = { type = "description", order = order + 0.2, width = "full", fontSize = "medium",
            hidden = function() return type(t[k]) ~= "table" or #t[k] == 0 end,
            name = function()
                local o = {}
                for _, id in ipairs(type(t[k]) == "table" and t[k] or {}) do o[#o + 1] = H.SpellName(id) .. "  [" .. id .. "]" end
                return table.concat(o, "\n")
            end }
    end
    -- a field that only matters for some settings (seconds left once a comparison is chosen ...); hiding never changes saved values
    for _, key in ipairs({ k, k .. "Search", k .. "ID", k .. "Name", k .. "Pick", k .. "Names" }) do
        local o = row[key]
        if o then
            if f.desc and not o.desc then o.desc = f.desc end
            if f.showIf then
                local prev = o.hidden
                o.hidden = function()
                    if not f.showIf(t) then return true end
                    if type(prev) == "function" then return prev() end
                    return prev and true or false
                end
            end
        end
    end
end

function ns.BuildExtraTriggerArgs(rule, H)
    local args = {}
    if type(rule.extra) ~= "table" then ns.NormalizeExtra(rule) end
    local X = rule.extra
    X.list = X.list or {}
    local function onN() H.Changed(rule); H.Notify() end

    args.xHeader = { type = "header", name = "Triggers", order = 0 }
    args.xHelp = { type = "description", order = 0.1, width = "full", fontSize = "medium",
        name = "A new rule has no triggers. Add the ones it needs, one at a time. By default every trigger has to be true; with two or more triggers, 'This rule is activated by' lets ANY trigger, or just one of them, switch the rule on. "
            .. "Each trigger shows a TRUE / FALSE / UNKNOWN light in its header. Talents and Load conditions are on their own tabs." }

    -- Cooldown and Buff / Aura are added from the same menu; the other types become rows. Already-added built-ins are not offered again.
    local BUILTIN = { _cooldown = "Spell:  Cooldown / charges", _buff = "Aura:  Buff / Aura" }
    local function AddChoices()
        local values, order = {}, {}
        if not ns.CooldownUsed(rule) then values._cooldown = BUILTIN._cooldown end
        if not ns.BuffUsed(rule) then values._buff = BUILTIN._buff end
        for _, key in ipairs(ORDER) do
            local d = TYPES[key]
            if not d.hideFromMenu and (key ~= "buffAura" or ns.BuffUsed(rule)) then values[key] = d.group .. ":  " .. d.label end   -- a further aura trigger is offered once the built-in one is taken
        end
        for k in pairs(values) do order[#order + 1] = k end
        table.sort(order, function(a, b) return values[a] < values[b] end)
        return values, order
    end
    args.xAdd = { type = "select", name = "Add a trigger", order = 0.2, width = "double",
        desc = "Pick a trigger type. Its options appear below.",
        values = function() local v = AddChoices(); return v end,
        sorting = function() local _, o = AddChoices(); return o end,
        get = function() return nil end,
        set = function(_, v)
            if v == "_cooldown" then local sq = ns.TriggerSequence(rule); rule.useCooldown = true; sq[#sq + 1] = "cd"; rule.trigOrder = sq; onN(); return end
            if v == "_buff" then local sq = ns.TriggerSequence(rule); rule.useBuff = true; sq[#sq + 1] = "buff"; rule.trigOrder = sq; onN(); return end
            if not TYPES[v] then return end
            if #X.list >= MAX_ROWS then ns.Print("a rule can hold at most " .. MAX_ROWS .. " additional triggers"); return end
            local row = { type = v }
            for kk, vv in pairs(TYPES[v].new or {}) do row[kk] = vv end
            local sq = ns.TriggerSequence(rule)
            X.list[#X.list + 1] = row
            sq[#sq + 1] = "x"; rule.trigOrder = sq
            onN()
        end }
    -- Which trigger activates the rule. Default = ALL (every trigger, as before). ANY = one true trigger is enough. Or one trigger alone decides;
    -- the others then still show their lights but do not gate the rule. Conditions can still read every trigger individually.
    local function ActivateChoices()
        local vals, order = { all = "ALL triggers must be true (default)", any = "ANY trigger: one true trigger activates the rule" }, { "all", "any" }
        local Q = ns.TriggerPositions(rule)
        for _, tk in ipairs(Q.seq) do
            if tk == "cd" then vals.cd = "Only " .. ns.TriggerChoiceLabel(rule, "cd", nil, Q.cd or 1, "Cooldown"); order[#order + 1] = "cd"
            elseif tk == "buff" then vals.buff = "Only " .. ns.TriggerChoiceLabel(rule, "buff", nil, Q.buff or 1, "Buff / Aura"); order[#order + 1] = "buff" end
        end
        for j, t in ipairs(X.list) do
            local d = TYPES[t.type]
            local k = "x" .. j
            vals[k] = "Only " .. ns.TriggerChoiceLabel(rule, "x", j, Q.xs[j] or j, d and d.label or "unknown type"); order[#order + 1] = k
        end
        return vals, order
    end
    args.xActivate = { type = "select", name = "This rule is activated by", order = 0.25, width = "double",
        desc = "Sets what switches the rule on: ALL needs every trigger true, ANY needs one, or one trigger decides alone. Conditions can still read every trigger.",
        hidden = function() return #ns.TriggerSequence(rule) < 2 end,
        values = function() local v = ActivateChoices(); return v end,
        sorting = function() local _, o = ActivateChoices(); return o end,
        get = function()
            local v = ActivateChoices()
            local m = rule.trigMode or "all"
            return v[m] and m or "all"
        end,
        set = function(_, v) rule.trigMode = (v ~= "all") and v or nil; onN() end }
    args.xMode = H.Sel(X, "mode", "Combine the additional triggers", 0.3,
        { all = "ALL of them must be true", any = "ANY one of them is enough" }, { "all", "any" }, onN,
        { width = "double", hidden = function() return #X.list < 2 or (rule.trigMode ~= nil and rule.trigMode ~= "all") end,
          desc = "Combines the additional triggers with each other; blank counts as ALL. Not used while 'This rule is activated by' is ANY or one trigger." })

    local P = ns.TriggerPositions(rule)
    for j, t in ipairs(X.list) do
        local def = TYPES[t.type]
        local pos = P.xs[j] or j
        local row = {}
        if def then
            row.note = { type = "description", order = 0, width = "full", fontSize = "small", name = def.note }
            for i, f in ipairs(def.fields) do FieldArgs(rule, t, f, H, i, row) end
        else
            row.note = { type = "description", order = 0, width = "full",
                name = "|cffff5555This trigger type ('" .. tostring(t.type) .. "') is not known to this version. It never fires; remove it or update XayaUI.|r" }
        end
        if ns.TriggerCombatNote then
            row.combat = { type = "description", order = 89, width = "full", fontSize = "small",
                hidden = function() local okc, n = pcall(ns.TriggerCombatNote, rule, "x", t); return not (okc and n) end,
                name = function() local okc, n = pcall(ns.TriggerCombatNote, rule, "x", t); return okc and n or "" end }
        end
        row.status = { type = "description", order = 90, width = "double", fontSize = "medium",
            name = function()
                local r, d = ns.CheckTrigger(t)
                local word = (r == true and "|cff55ff55true|r") or (r == false and "|cffff5555false|r") or "|cffffd100unknown|r"
                return "Right now: " .. word .. (d and ("  -  " .. tostring(d)) or "")
            end }
        local function removeFn()
            if ns.IsEditLocked and ns.IsEditLocked(rule) then return end
            if ns.RecycleTrigger then ns.RecycleTrigger(rule, "x", j) end   -- FA-11: to the Recycle Bin (no prompt), restorable
            local sq = ns.TriggerSequence(rule)
            local seen = 0
            for i, tk in ipairs(sq) do
                if tk == "x" then seen = seen + 1; if seen == j then table.remove(sq, i); break end end
            end
            if ns.RemapOutcomeRefs then   -- outcome conditions that pointed at this row lose it; later rows shift down by one
                ns.RemapOutcomeRefs(rule, function(n) if n == j then return nil elseif n > j then return "x" .. (n - 1) end return "x" .. n end)
            end
            table.remove(X.list, j)
            rule.trigOrder = sq
            onN()
        end
        local function copyFn()
            if #X.list >= MAX_ROWS then ns.Print("a rule can hold at most " .. MAX_ROWS .. " additional triggers"); return end
            table.insert(X.list, j + 1, ns.Copy(t))
            local sq = ns.TriggerSequence(rule)
            local seen = 0
            for i, tk in ipairs(sq) do
                if tk == "x" then seen = seen + 1; if seen == j then table.insert(sq, i + 1, "x"); break end end
            end
            rule.trigOrder = sq
            if ns.RemapOutcomeRefs then ns.RemapOutcomeRefs(rule, function(n) if n > j then return "x" .. (n + 1) end return "x" .. n end) end
            onN()
        end
        local title = ns.TriggerHeader(rule, "x", j, pos, def and def.label or "Unknown trigger")
        row.rename = ns.TriggerNameArg(rule, "x", j, 0.5, onN)
        local actions = function()
            return {
                up = (pos > 1) and function() ns.MoveTrigger(rule, pos, -1); onN() end or false,
                down = (pos < #P.seq) and function() ns.MoveTrigger(rule, pos, 1); onN() end or false,
                copy = copyFn, del = removeFn,
            }
        end
        if ns.GatedPane and ns.SkinRows and ns.SkinRows() then
            row.rename = nil   -- skin on: the name is typed in the header itself
            local pane = ns.GatedPane(rule, "trig_x" .. j, title, pos * 100, function() return true end, row)
            ns.TriggerPaneHeader(pane, rule, "x", j, title, onN)
            pane.args.hdr.arg.xuiActions = actions
            args["x" .. j] = pane
            ns.TriggerDivider(args, "divx" .. j, pos)
        else
            row.remove = { type = "execute", name = "Remove", order = 91, width = "half", func = removeFn }
            row.up = { type = "execute", name = "Up", order = 92, width = "half", hidden = function() return pos <= 1 end, func = function() ns.MoveTrigger(rule, pos, -1); onN() end }
            row.down = { type = "execute", name = "Down", order = 93, width = "half", hidden = function() return pos >= #P.seq end, func = function() ns.MoveTrigger(rule, pos, 1); onN() end }
            args["x" .. j] = { type = "group", inline = true, order = pos * 100, name = title, args = row }
            ns.TriggerDivider(args, "divx" .. j, pos)
        end
    end
    return args
end
