-------------------------------------------------------------------------------
-- Core.lua : namespace, saved variables, rule defaults, slash commands.
-------------------------------------------------------------------------------
local addonName, ns = ...

ns.name = addonName; XayaUI_NS = ns -- deliberate global: sibling addons (XayaUI_Chat, XayaUI_QoL, XayaUI_Bonus, XayaUI_Reskin, XayaUI_Options) share this namespace; they plug in through Modules.lua
-- #286: a button built from Blizzard's red UIPanelButtonTemplate takes XayaUI's flat look now and every time it is shown, so it also
-- follows the skin switch. The look comes from the "buttonSkin" service (Modules.lua ns.Service), which the settings addon provides;
-- core never calls the settings addon by name. Without it (not loaded yet, or switched off) the button keeps Blizzard's look.
function ns.FlatButton(b, primary)
    if not b then return b end
    local function apply(self)
        local svc = ns.Service and ns.Service("buttonSkin")
        if svc and type(svc.Apply) == "function" then pcall(svc.Apply, self, primary) end
    end
    apply(b)
    if b.HookScript then b:HookScript("OnShow", apply) end
    return b
end
ns.rules = nil -- set at ADDON_LOADED to CueRulesDB.rules
-- the settings window's rebuild timing switch: { show = bool } (XayaUI Dev Assist's /xui debug perf ui sets it; XayaUI_Options and
-- ns.NewFolder below read it). Core 0.6.56: declared here, as the command that made it moved to Dev Assist.
ns.perf = nil

-- "Not chosen / none" helpers. Dropdowns start blank (nil) so a choice is forced;
-- "none" (or legacy "any") is an explicit "ignore this".
function ns.Ignored(s) return s == nil or s == "" or s == "none" or s == "any" end
function ns.Val(v) if v == nil or v == "" or v == "none" then return nil end return v end

-- A message that names another player (or anything else personal): shown like ns.Print, but never kept anywhere a report reads:
-- not in the debug record, not in the console's line buffer (the bug report and "Copy" read it), not in collected output.
local privateMsg = false
function ns.PrintPrivate(...)
    privateMsg = true
    local ok, err = pcall(ns.Print, ...)
    privateMsg = false
    if not ok then error(err, 0) end
end
function ns.Print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    local text = table.concat(parts, " ")
    if ns._capture and not privateMsg then ns._capture[#ns._capture + 1] = text; return end   -- (DebugRecord.lua ns.CaptureOutput)
    if ns.RecordLine and not privateMsg then ns.RecordLine("msg", text) end
    -- where messages go (DebugRecord.lua, Settings > Debugging): chat, the XayaUI console window, or both. core 0.6.50, whatever the
    -- setting: a command typed in the console window, and any /xui debug command, prints in the console window (ns.consoleRunning,
    -- Console.lua ns.RunInConsole); the /xui status and /xui auras shortcuts print in chat (ns.chatRunning, RunInChat below). The
    -- console wins when both are set (a shortcut typed in the console window prints there).
    local dest = (ns.consoleRunning and "console") or (ns.chatRunning and "chat") or (ns.MessageDest and ns.MessageDest() or "chat")
    -- (Xaya 2026-11-06, asked whether messages set to the chat window should also show in the open console window: "Only xui console
    -- messages should display". So the console window shows only what is sent to it.)
    if dest ~= "chat" and ns.ConsoleMessage and pcall(ns.ConsoleMessage, text, false, privateMsg) and dest == "console" then return end
    print("|cff33ccffXayaUI|r: " .. text)
end

-------------------------------------------------------------------------------
-- XayaUI's own Lua errors (core 0.6.56; REQUEST-LOG #82, Xaya 2026-11-06: the debug record is "only there to catch errors and bugs
-- that might be expected within a live, user-facing version of the addon. these should have error codes built out, auto detection, and
-- auto documenting with a simple debug report that someone can directly send to me"). The game's error handler is chained, never
-- replaced: whatever handler was set before (the game's own error frame, BugSack, another addon's) is still called with the same
-- message, every time. Only an error raised in a XayaUI file (the file named at the start of the message, else the first file the stack
-- names: Interface/AddOns/XayaUI*/...) is recorded, with its code (DebugRecord.lua ns.RecordError: XUI-E001 for core, E002 the settings
-- window, ...). Nothing here runs unless an error happens: no event, no timer, no per-frame work.
-- With Advanced Debugging on (Settings > Debugging, on by default) the error is also shown where XayaUI's messages go.
-------------------------------------------------------------------------------
-- The XayaUI folder an error came from, or nil: the message's own location ("Interface/AddOns/XayaUI_Chat/Core.lua:12: ...") decides;
-- a message without one (error(msg, 0)) is decided by the first addon file in the stack.
function ns.ErrorFolder(text, stack)
    text = tostring(text or "")
    local loc = text:match("^%s*([^\n]-%.lua):%d+:")
    if loc then
        local folder = loc:match("AddOns[/\\](XayaUI[%w_]*)[/\\]")
        return folder
    end
    for path in tostring(stack or ""):gmatch("([^\n%[%]\"']-%.lua)") do
        local addon = path:match("AddOns[/\\]([%w_%-]+)[/\\]")
        if addon then return addon:match("^XayaUI[%w_]*$") and addon or nil end
    end
    return nil
end
do
    local prevHandler = geterrorhandler()
    seterrorhandler(function(msg)
        local text = tostring(msg)
        local okS, stack = pcall(debugstack, 2, 12, 0)
        stack = (okS and type(stack) == "string") and stack or ""
        local okF, folder = pcall(ns.ErrorFolder, text, stack)
        folder = okF and folder or nil
        if folder and ns.RecordError then pcall(ns.RecordError, text, stack, folder) end   -- (DebugRecord.lua; nothing while it is off)
        local ok, on = pcall(function() return CueRulesDB and CueRulesDB.ui and CueRulesDB.ui.advancedDebug end)
        local mine = ok and on and folder ~= nil
        -- (core 0.6.50) an error while a command typed in the console window runs (Console.lua ns.ConsoleRun) is that command's:
        -- shown in the console window, Advanced Debugging on or off
        local typed = ns.consoleRunning
        if mine or typed then
            -- the same place as XayaUI's messages (DebugRecord.lua): the console window, chat, or both
            local dest = typed and "console" or (ns.MessageDest and ns.MessageDest() or "chat")
            local shown = dest ~= "chat" and ns.ConsoleMessage and pcall(ns.ConsoleMessage, text, true)
            if (dest ~= "console" or not shown) and DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[XayaUI Error]|r " .. text, 1, 0.35, 0.35)
            end
        end
        if prevHandler then return prevHandler(msg) end
    end)
end

-- In-game event log (shown in the settings window's debug console tray).
ns.logBuf = {}
-- ns.LogKind(kind, fmt, ...): the same, with the debug record's category for the line ("rule", "snapshot" ...; DebugRecord.lua)
local logKind = "log"
function ns.LogKind(kind, fmt, ...)
    logKind = kind or "log"
    local ok, err = pcall(ns.Log, fmt, ...)
    logKind = "log"
    if not ok then error(err, 0) end
end
-- one line into ns.logBuf (the console window, its Copy button, the bug report and the settings window's strip read it)
function ns.LogAppend(line)
    local b = ns.logBuf
    b[#b + 1] = line
    ns.logSerial = (ns.logSerial or 0) + 1   -- (Console.lua: which lines a closed console window has not drawn yet)
    local n = #b
    if n > 350 then   -- trim in one pass (down to 300) instead of shifting the whole array on every line
        for i = 1, 300 do b[i] = b[n - 300 + i] end
        for i = 301, n do b[i] = nil end
    end
end
function ns.Log(fmt, ...)
    local kind = logKind
    local msg = (select("#", ...) > 0) and fmt:format(...) or fmt
    local line = ("|cff888888%.1f|r %s"):format(GetTime() % 10000, msg)
    ns.LogAppend(line)
    ns.Fire("LOG", line)   -- the window's debug tray listens (XayaUI_Options)
    if ns.ConsoleSink then ns.ConsoleSink(line) end   -- the separate console window (Console.lua)
    if ns.RecordLine then ns.RecordLine(kind, msg) end   -- the saved debug record (DebugRecord.lua, Advanced Debugging)
end

-- Deep-copy helper for defaults.
local function Copy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = Copy(v) end
    return o
end
ns.Copy = Copy

-- Fill missing keys from defaults without overwriting saved values.
local function Merge(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = Copy(v)
        elseif type(v) == "table" and type(dst[k]) == "table" then
            Merge(dst[k], v)
        end
    end
end

ns.RULE_DEFAULTS = {
    name = "New rule",
    enabled = true,

    -- Cooldown side
    spellID = 0,            -- spell whose cooldown/charges are checked (0 = ignore)
    maxCharges = 0,         -- manual override; used only if the game reports none
    cdState = nil,          -- (blank) | none | hasCharge | ready | notReady | empty   [required]

    -- Buff side
    buffID = 0,             -- aura spell ID (0 = ignore)
    buffState = nil,        -- (blank) | none | missing | present   [required]

    -- Talent requirements: a list of { id = spellID, state = "known" | "notKnown" } combined by talentMode
    talents = {},
    talentMode = nil,       -- (blank) | none | all | any   blank and none = no talent requirement (Conditions.lua CheckTalents); all = every talent must match, any = at least one
    -- Additional triggers (Triggers.lua): typed rows combined by extra.mode (blank / all = every row, any = one is enough),
    -- then ANDed with the cooldown, buff, talent and load settings. Plain data only: no code is ever stored here.
    extra = { list = {} },
    uid = nil,              -- set when the rule first gets an outcome (Outcomes.lua)
    parentUid = nil,        -- set on an outcome: the uid of the rule whose triggers it follows
    when = { list = {} },   -- outcome combination rows: { ref, neg, op = "and" | "or" }
    useCooldown = false,    -- the Cooldown trigger section was added by hand (also shown whenever it holds data)
    useBuff = false,        -- same for Buff / Aura
    folder = nil,           -- id of the user folder this rule sits in (nil = top level)

    -- Load conditions (context): tri-state (blank/none = ignore) | yes | no
    load = {
        mode = nil,           -- (blank/all) = every active condition must match | any = at least one
        instanceTypes = {},   -- set of instance types; empty = any
        -- combat, group, raid, instance, mythicPlus, encounter, mounted, resting, specID, role: blank until chosen
    },

    sound = {
        enabled = false,    -- chosen per rule (see "+ New rule")
        source = "kit",     -- kit | lsm | file | tts (tts: value = the text, voice / rate / ttsVolume beside it)
        value = "",
        -- channel: blank until chosen (Master is used when blank)
    },
    repeatSec = 0,          -- 0 = play once per false->true transition

    visual = {
        enabled = false,
        -- trigger: blank until chosen (condition | buffActive); nothing shows while blank
        -- kind: blank until chosen (file | atlas | spellicon)
        tex = "",
        w = 128, h = 128,
        x = 0, y = 0,
        alpha = 1,
        additive = false,
        glow = false,
        -- outline glow: style auto | border | shape. border = pixel border (width / gap / color) + optional soft glow; shape = follows the art
        outline = { enabled = false, style = "auto", width = 2, gap = 0, color = { 1, 0.82, 0, 1 }, pulse = false,
            borderOn = true, glowOn = true, glowSize = 8, glowAlpha = 0.6, glowSame = true, glowColor = { 1, 0.82, 0, 1 } },
        keepAspect = true,     -- Width and Height change together (the ratio at the moment you move a slider)
        iconW = 0, iconH = 0,  -- size of the art inside the display (0 = same as the display; larger crops it)
        fadeGrey = false,      -- fade gradually as the buff runs out (gray by default, or to fadeColor)
        -- fadeMode: blank/none = gray (desaturate) | color | transparent
        fadeColor = { 1, 0.1, 0.1, 1 },
        fadeAlpha = false,     -- also fade the opacity as the buff runs out (down to fadeAlphaMin x opacity)
        fadeAlphaMin = 0.15,
        fadeAlphaMax = 1,      -- opacity multiplier at full duration (fade goes fadeAlphaMax -> fadeAlphaMin)
        texAlpha = 1,          -- opacity of the BASE texture on its own (alpha = overall opacity of everything)
        overlay = {            -- optional second texture layer on top of the base
            enabled = false,
            -- source: blank/none = same art as the base | other (pick kind + tex below)
            tex = "",
            tint = { 1, 1, 1, 1 }, desaturate = false, additive = false,
            alpha = 1,         -- opacity of the overlay on its own
            -- Progress-texture rules (visual.fill.enabled) link the base's opacity/graying to this layer by
            -- default: the overlay never grays and never dims below 1, the base opens at a reduced opacity that
            -- tracks Overlay opacity to keep their original ratio, and the base grays automatically iff a tint is
            -- selected (desaturate mirrors recolor). advanced=true breaks that link so all of those are manual again.
            advanced = false,
        },
        fill = {               -- progress-bar style wipe as the buff runs out (readable aura times only)
            enabled = false,
            -- dir (bottom|top|left|right): which edge the art shrinks toward; blank = bottom
            reverse = false,   -- fill up instead of drain
            min = 0, max = 1,  -- fraction of the art shown at 0% / 100% time remaining
        },
        flash = { enabled = false, threshold = 3, speed = 3 },  -- pulse the opacity when <= threshold seconds remain
        desatOnCD = false,     -- desaturate while the cooldown spell is on cooldown
        requireOnBar = false,  -- only show while this rule's spell/buff is currently placed on an action bar
        oocAlpha = 1,          -- opacity multiplier while out of combat (1 = same)
        border = { enabled = false, size = 1, color = { 0, 0, 0, 1 } },
        bg = { enabled = false, color = { 0, 0, 0, 0.5 } },
        zoom = 0,              -- extra crop 0-0.3 (spell icons keep their default crop)
        count = {              -- aura stacks / spell charges text (experimental under Midnight secrecy)
            enabled = false,
            -- source (stacks|charges), place, anchor: blank until chosen (fallback stacks / inner / bottom right)
            x = 0, y = 0, size = 14, color = { 1, 1, 1, 1 },
        },
        absorb = {             -- shield / absorb amount text (experimental under Midnight secrecy)
            enabled = false,
            -- source (total|aura), place, anchor, outline, font: blank until chosen (fallback total / inner / top)
            abbreviate = true, hideZero = true,
            x = 0, y = 0, size = 18, color = { 0.9, 0.9, 1, 1 },
        },
        rotation = 0,          -- degrees, 0-360
        flipH = false, flipV = false,
        recolor = false, desaturate = false, tint = { 1, 1, 1, 1 },
        text = {               -- buff duration text
            enabled = false,
            -- place (inner|outer), anchor (CENTER TOP ...), outline: blank until chosen (fallbacks: inner / center / outline)
            x = 0, y = 0,
            size = 20, color = { 1, 1, 1, 1 },
            decimals = true,
            decimalBelow = 5,      -- show tenths only below this many seconds
        },
    },
}

-- QoL "stats text" box defaults (see QoL.lua)
ns.QOL_BOX_DEFAULTS = {
    name = "Stats",
    enabled = true,
    format = "Crit {crit}   Haste {haste}\nMastery {mastery}   Vers {vers}",
    size = 14,   -- outline / justify / showCombat: blank until chosen (fallbacks: outline / left / always)
    color = { 1, 1, 1, 1 }, alpha = 1,
    decimals = 1,
    x = 0, y = -250,
}

-- Buff bars (own umbrella in the UI). Dropdown-backed fields stay blank until chosen.
ns.BAR_DEFAULTS = {
    name = "Buff bar",
    enabled = true,
    buffID = 0,
    width = 220, height = 22,
    x = 0, y = -120,
    alpha = 1,
    fillColor = { 0.25, 0.62, 1, 1 },
    bgColor = { 0, 0, 0, 0.55 },
    reverse = false,          -- false: bar drains as time runs out; true: bar fills up
    spark = false,
    vertical = false,
    borderSize = 1, borderColor = { 0, 0, 0, 1 },
    -- visibility (always|hideInactive|combat|noCombat), icon (none|left|right), texture,
    -- nameMode (aura|custom|none), timer/name anchors: blank until chosen (fallbacks documented in Bars.lua)
    customName = "",
    nameSize = 12, timerSize = 12, stackSize = 12,
    showName = true, showTimer = true, showStacks = false,
    decimals = true, decimalBelow = 5,
}
ns.BAR_GROUP_DEFAULTS = { spacing = 3, x = 0, y = -120 }   -- layout blank = manual positions

function ns.NewBar() return Copy(ns.BAR_DEFAULTS) end

-- Rename every group whose id is not "f" + digits to one that is, and re-point rules and child groups. Returns how many were renamed.
function ns.FixFolderIds()
    local used, map, n = {}, {}, 0
    for _, f in ipairs(ns.folders) do used[f.id] = true end
    for _, f in ipairs(ns.folders) do
        if type(f.id) == "string" and not f.id:match("^f%d+$") then
            local id
            repeat id = "f" .. tostring(time()) .. tostring(math.random(1000, 9999)) until not used[id]
            used[id] = true; map[f.id] = id; n = n + 1
        end
    end
    if n == 0 then return 0 end
    for _, f in ipairs(ns.folders) do
        if f.parent and map[f.parent] then f.parent = map[f.parent] end
        if map[f.id] then f.id = map[f.id] end
    end
    for _, r in ipairs(ns.rules or {}) do if r.folder and map[r.folder] then r.folder = map[r.folder] end end
    return n
end
-- Where a group came from (#372 / CHAT-3d, Xaya: "config includes folder name, folder type, and original character / source of
-- creation"): origin = { by = "Name-Realm" of the character that made it, how = "made" | "default" | "imported" | ..., at = time() }.
-- Shown on the group page's Config tab; groups made before this have none ("not recorded").
function ns.CharacterKey()
    local n = UnitName and UnitName("player")
    local r = GetRealmName and GetRealmName()
    if type(n) ~= "string" or n == "" then return nil end
    return (type(r) == "string" and r ~= "") and (n .. "-" .. r) or n
end
-- an origin read from saved or imported data: plain text only (it is shown as text), short, or nil
function ns.CleanOrigin(o)
    if type(o) ~= "table" then return nil end
    local function txt(v, max) if type(v) ~= "string" then return nil end; v = v:gsub("|", ""):sub(1, max); return v ~= "" and v or nil end
    local out = { by = txt(o.by, 64), how = txt(o.how, 24), at = (type(o.at) == "number" and o.at > 0) and math.floor(o.at) or nil }
    return (out.by or out.how or out.at) and out or nil
end
function ns.NewFolder(name, parent, how)
    local id
    repeat
        id = "f" .. tostring(time()) .. tostring(math.random(1000, 9999))
        local dup
        for _, x in ipairs(ns.folders) do if x.id == id then dup = true; break end end
    until not dup
    local f = { id = id, name = name or "Folder", parent = parent }   -- parent = id of the folder this one is nested in (nil = top level)
    f.origin = { by = ns.CharacterKey(), how = how or "made", at = time and time() or nil }
    ns.folders[#ns.folders + 1] = f
    if ns.perf and ns.perf.show and debugstack then   -- /xui debug perf ui: say who created a group (finds groups that appear on their own)
        local src = (debugstack(2, 1, 0) or ""):match("([^\n]+)") or "?"
        print("|cffffd100XayaUI|r group created: '" .. tostring(f.name) .. "' by " .. src)
    end
    return f
end

-------------------------------------------------------------------------------
-- Step index. While the engine runs one step (ns.BeginStepIndex .. ns.EndStepIndex), the hot lookups below (group by id,
-- rule by uid, a rule's cues / conditions / outcomes) answer from maps built once for that step instead of scanning the
-- whole rule or group list on every call; with a few hundred rules that scan, repeated for every rule, was most of the
-- engine's time. Outside a step (the options window, slash commands) every lookup scans as before, so edits are seen at
-- once. Lists handed out during a step are shared: callers read them, never change them.
-------------------------------------------------------------------------------
local stepIdx   -- nil outside a step
local EMPTY = setmetatable({}, { __newindex = function() error("XayaUI: the step index lists are read-only") end })
ns.EMPTY_LIST = EMPTY

-- #309: one step table, emptied at every step start (no new table per step); the folder and rule indexes below are kept between
-- steps and reused only while the lists they were built from are unchanged (checked entry by entry, no edit signal needed).
local stepTable = {}
function ns.BeginStepIndex() for k in pairs(stepTable) do stepTable[k] = nil end; stepIdx = stepTable end
function ns.EndStepIndex() stepIdx = nil end
-- true while the engine runs a step: per-step caches may be used (and reused tables handed out)
function ns.InStep() return stepIdx ~= nil end
-- Per-step memo tables: one table per name, emptied at the start of every step (reused, so no garbage). Outside a step: nil.
local memos, memoStep = {}, {}
local stepSerial = 0
function ns.StepMemo(name)
    if not stepIdx then return nil end
    local t = memos[name]
    if not t then t = {}; memos[name] = t end
    if memoStep[name] ~= stepSerial then
        for k in pairs(t) do t[k] = nil end
        memoStep[name] = stepSerial
    end
    return t
end
local BeginStepIndex0 = ns.BeginStepIndex
function ns.BeginStepIndex() stepSerial = stepSerial + 1; BeginStepIndex0() end

-- Kept-index check (#309): an index built from a list is reused while the list still holds the same entries, in the same order, with
-- the same identifying fields. Any difference (an entry added, removed, moved, or a uid / parentUid / id / cue flag changed, whether or
-- not the edit announced itself) rebuilds the index exactly as a fresh build would.
local fiKept, fiN, fiF, fiId = nil, -1, {}, {}
local function FolderIndexValid(list)
    local n = #list
    if not fiKept or n ~= fiN then return false end
    for i = 1, n do local f = list[i]; if fiF[i] ~= f or fiId[i] ~= f.id then return false end end
    return true
end
local function FolderIndex()
    local fi = stepIdx.folders
    if not fi then
        local list = ns.folders or EMPTY
        if FolderIndexValid(list) then
            fi = fiKept
        else
            fi = {}
            local n = #list
            for i = 1, n do
                local f = list[i]
                if f.id ~= nil and fi[f.id] == nil then fi[f.id] = f end
                fiF[i], fiId[i] = f, f.id
            end
            for i = n + 1, fiN do fiF[i], fiId[i] = nil, nil end
            fiKept, fiN = fi, n
        end
        stepIdx.folders = fi
    end
    return fi
end

-- parents[uid] = first parent rule with that uid; kids[uid] = every rule whose parentUid is uid, in rule order
local riKept, riN, riR, riU, riP, riC = nil, -1, {}, {}, {}, {}
local function RuleIndexValid(list)
    local n = #list
    if not riKept or n ~= riN then return false end
    for i = 1, n do
        local r = list[i]
        if riR[i] ~= r or riU[i] ~= r.uid or riP[i] ~= r.parentUid or riC[i] ~= (r.isCue and true or false) then return false end
    end
    return true
end
local function RuleIndex()
    local ri = stepIdx.rules
    if not ri then
        local list = ns.rules or EMPTY
        if RuleIndexValid(list) then
            ri = riKept   -- same rules, same order, same uid / parentUid / cue flags: the kept index (and its cue / condition lists) still holds
        else
            local parents, kids = {}, {}
            local n = #list
            for i = 1, n do
                local r = list[i]
                local pu = r.parentUid
                if pu ~= nil then
                    local l = kids[pu]
                    if not l then l = {}; kids[pu] = l end
                    l[#l + 1] = r
                elseif type(r.uid) == "string" and parents[r.uid] == nil then
                    parents[r.uid] = r
                end
                riR[i], riU[i], riP[i], riC[i] = r, r.uid, pu, (r.isCue and true or false)
            end
            for i = n + 1, riN do riR[i], riU[i], riP[i], riC[i] = nil, nil, nil, nil end
            ri = { parents = parents, kids = kids, cues = {}, conds = {} }
            riKept, riN = ri, n
        end
        stepIdx.rules = ri
    end
    return ri
end

-- During a step: the parent rule for a parentUid (nil when not in a step: the caller scans).
function ns.StepParentOf(rule)
    if not stepIdx then return nil, false end
    local uid = rule.parentUid
    if type(uid) ~= "string" or uid == "" then return nil, true end
    local p = RuleIndex().parents[uid]
    if p == rule then p = nil end
    return p, true
end

-- During a step: a parent's children, filtered by kind ("all" / "cues" / "conds"); nil when not in a step.
function ns.StepChildrenOf(p, kind)
    if not stepIdx then return nil end
    local uid = p.uid
    if type(uid) ~= "string" then return EMPTY end
    if p.parentUid == uid then return nil end   -- a rule naming itself as parent: rare, let the caller scan
    local ri = RuleIndex()
    local all = ri.kids[uid]
    if not all then return EMPTY end
    if kind == "all" then return all end
    local cache = (kind == "cues") and ri.cues or ri.conds
    local l = cache[uid]
    if not l then
        l = {}
        local wantCue = kind == "cues"
        for i = 1, #all do local r = all[i]; if (r.isCue and true or false) == wantCue then l[#l + 1] = r end end
        cache[uid] = l
    end
    return l
end

function ns.FolderById(id)
    if not id then return nil end
    if stepIdx then return FolderIndex()[id] end
    for _, f in ipairs(ns.folders or {}) do if f.id == id then return f end end
end

function ns.FolderOf(rule)
    return ns.FolderById(rule.folder)
end

-- Folder load override. folder.loadOverride = nil | "never" | "always". The nearest folder (starting at the given id, then its
-- parents) that sets one wins. Nothing is written to the rules, so a rule that leaves the folder is back to its own load settings.
-- Returns the override and the folder that sets it.
function ns.FolderLoadOverrideFrom(folderId)
    local id, guard = folderId, 0
    while id and guard < 32 do
        local f = ns.FolderById(id)
        if not f then return nil end
        if f.loadOverride == "never" or f.loadOverride == "always" then return f.loadOverride, f end
        id, guard = f.parent, guard + 1
    end
    return nil
end
function ns.FolderLoadOverride(rule)
    return ns.FolderLoadOverrideFrom(rule and rule.folder)
end

-- Default top-level categories. Created once per profile (flag ui.defaultFolders); a top-level folder that already has the same
-- name is adopted rather than duplicated; a deleted default is not brought back unless force is true (the All Rules page button).
-- The category a rule sits in decides its KIND: Display Cues = visual only, Sound Cues = sound only, everything else
-- (Hybrid Cues, Advanced Cue Tracking, custom folders, unfiled rules) = both.
ns.DEFAULT_FOLDERS = {
    { key = "display",  name = "Display Cues",           note = "Default category. Visual-only rules: texture, icon, or text. No sound options." },
    { key = "sound",    name = "Sound Cues",             note = "Default category. Sound-only rules. No display options." },
    { key = "hybrid",   name = "Hybrid Cues",            note = "Default category. Rules with both a display and a sound." },
    { key = "advanced", name = "Advanced Cue Tracking",  note = "Default category. Rules that combine several conditions (cooldown state, buff, talents, load conditions). Also the intended home for combination rules once they exist." },
    { key = "cursor",   name = "Mouse Cursor Cues",      note = "Default category. Its settings live in QoL Elements > Cursor Tracker (QoL Elements is switched off for now)." },
}
local OLD_DEFAULT_NAMES = { advanced = "Advanced Rule Tracking", cursor = "Mouse Cursor" }
function ns.DefaultFolderInfo(key)
    for i, d in ipairs(ns.DEFAULT_FOLDERS) do if d.key == key then return d, i end end
end
local DEFAULTS_VERSION = 3
function ns.EnsureDefaultFolders(force)
    local ui = CueRulesDB and CueRulesDB.ui
    if not ui or not ns.folders then return 0 end
    if (ui.defaultFoldersV or 0) >= DEFAULTS_VERSION and not force then return 0 end
    -- profiles that already had the three original defaults only gain the new Hybrid category (a default the user deleted stays deleted)
    local upgrading = ui.defaultFolders and not force
    ui.defaultFolders = true
    ui.defaultFoldersV = DEFAULTS_VERSION
    local added = 0
    for _, d in ipairs(ns.DEFAULT_FOLDERS) do
        local have
        for _, f in ipairs(ns.folders) do
            if not f.parent and (f.default == d.key
                or (not f.default and type(f.name) == "string" and (f.name:lower() == d.name:lower()
                    or (OLD_DEFAULT_NAMES[d.key] and f.name:lower() == OLD_DEFAULT_NAMES[d.key]:lower())))) then
                have = f; break
            end
        end
        if have then
            have.default = d.key
            if OLD_DEFAULT_NAMES[d.key] and have.name == OLD_DEFAULT_NAMES[d.key] then have.name = d.name end   -- renamed default
        elseif not upgrading or d.key == "hybrid" or d.key == "cursor" then
            local nf = ns.NewFolder(d.name, nil, "default")
            nf.default = d.key
            added = added + 1
        end
    end
    return added
end

-- Top-level ancestor folder of a folder id (or nil).
function ns.TopFolder(folderId)
    local id, guard, top = folderId, 0, nil
    while id and guard < 32 do
        local f = ns.FolderById(id)
        if not f then return top end
        top, id, guard = f, f.parent, guard + 1
    end
    return top
end
-- "display" | "sound" | "hybrid": decided by the top-level category the rule sits in; everything else counts as hybrid.
function ns.RuleKind(rule)
    local top = ns.TopFolder(rule and rule.folder)
    local d = top and top.default
    if d == "display" or d == "sound" then return d end
    if d == "cursor" then return "display" end   -- Mouse Cursor category: visual-only
    return "hybrid"
end
-- what = "visual" | "sound"
function ns.KindHas(rule, what)
    if rule.isCue then   -- a cue is exactly one kind of thing, whatever folder its rule is in
        if what == "sound" then return rule.cueKind == "sound" or rule.cueKind == "speech" end   -- speech plays through the sound pipeline
        return rule.cueKind ~= "sound" and rule.cueKind ~= "speech" and rule.cueKind ~= "custom"
    end
    -- a rule that has outcomes has no sound / display of its own: its outcomes carry them
    if ns.HasOutcomes and ns.HasOutcomes(rule) then return false end
    local k = ns.RuleKind(rule)
    if k == "hybrid" then return true end
    return (k == "display") == (what == "visual")
end

-- Sound channel enforced by a folder (nearest ancestor wins). Nothing is written to the rules.
function ns.FolderSoundChannelFrom(folderId)
    local id, guard = folderId, 0
    while id and guard < 32 do
        local f = ns.FolderById(id)
        if not f then return nil end
        if f.soundChannel and f.soundChannel ~= "" and f.soundChannel ~= "none" then return f.soundChannel, f end
        id, guard = f.parent, guard + 1
    end
end
-- The sound table the engine plays: the rule's own, with the folder-enforced channel applied.
function ns.EffectiveSound(rule)
    local s = rule and rule.sound
    if not s then return s end
    local ch = ns.FolderSoundChannelFrom(rule.folder)
    if not ch then return s end
    local c = {}
    for k, v in pairs(s) do c[k] = v end
    c.channel = ch
    return c
end

-- One-time: every rule that existed before the cue kinds counts as Hybrid. Whatever sat under Display Cues or Sound Cues
-- moves under Hybrid Cues (same-named subfolders are merged, nothing is deleted).
local function MergeFolderInto(src, dstParentId)
    local existing
    for _, f in ipairs(ns.folders) do
        if f ~= src and f.parent == dstParentId and f.name == src.name then existing = f; break end
    end
    if not existing then src.parent = dstParentId; return end
    for _, r in ipairs(ns.rules or {}) do if r.folder == src.id then r.folder = existing.id end end
    local kids = {}
    for _, f in ipairs(ns.folders) do if f.parent == src.id then kids[#kids + 1] = f end end
    for _, k in ipairs(kids) do MergeFolderInto(k, existing.id) end
    for i, f in ipairs(ns.folders) do if f == src then table.remove(ns.folders, i); break end end
end
function ns.MigrateToHybrid()
    local ui = CueRulesDB and CueRulesDB.ui
    if not ui or ui.hybridMigrated or not ns.folders or not ns.rules then return 0 end
    local hybrid
    for _, f in ipairs(ns.folders) do if not f.parent and f.default == "hybrid" then hybrid = f; break end end
    if not hybrid then return 0 end
    ui.hybridMigrated = true
    local moved = 0
    for _, key in ipairs({ "display", "sound" }) do
        local src
        for _, f in ipairs(ns.folders) do if not f.parent and f.default == key then src = f; break end end
        if src then
            for _, r in ipairs(ns.rules) do if r.folder == src.id then r.folder = hybrid.id; moved = moved + 1 end end
            local kids = {}
            for _, f in ipairs(ns.folders) do if f.parent == src.id then kids[#kids + 1] = f end end
            for _, k in ipairs(kids) do MergeFolderInto(k, hybrid.id) end
        end
    end
    -- count everything now under Hybrid for the message
    local n = 0
    for _, r in ipairs(ns.rules) do if ns.RuleKind(r) == "hybrid" and r.folder then n = n + 1 end end
    if n > 0 then ns.hybridMigratedCount = n end
    return n
end

-- One-time: every currently ACTIVE display (rule on + display on + a visual kind) becomes a progress texture
-- (visual.fill.enabled). Base art and the overlay layer are cropped together by that wipe, so they act as one unit.
-- The previous fill switch is kept in rule.progressBackup so it can be restored.
function ns.MigrateToProgress()
    local ui = CueRulesDB and CueRulesDB.ui
    if not ui or ui.progressMigrated or not ns.rules then return 0 end
    ui.progressMigrated = true
    local n = 0
    for _, r in ipairs(ns.rules) do
        local v = r.visual
        if r.enabled and type(v) == "table" and v.enabled and ns.KindHas(r, "visual") then
            if type(v.fill) ~= "table" then v.fill = { enabled = false, reverse = false, min = 0, max = 1 } end
            if not v.fill.enabled then
                r.progressBackup = { fillEnabled = false }
                v.fill.enabled = true
                n = n + 1
            end
        end
    end
    return n
end

-- Fonts: blank/none = the game's default font. Built-ins plus every LibSharedMedia font that is loaded.
local BUILTIN_FONTS = {
    frizqt = { "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
    arialn = { "Arial Narrow", "Fonts\\ARIALN.TTF" },
    skurri = { "Skurri", "Fonts\\SKURRI.TTF" },
    morpheus = { "Morpheus", "Fonts\\MORPHEUS.TTF" },
    -- bundled open-source fonts (SIL OFL, see Media\\Fonts\\OFL-*.txt). A new font file needs a full game restart to load.
    firasans = { "Fira Sans", "Interface\\AddOns\\XayaUI\\Media\\Fonts\\FiraSans-Regular.ttf" },
    lato = { "Lato", "Interface\\AddOns\\XayaUI\\Media\\Fonts\\Lato-Regular.ttf" },
    ptsans = { "PT Sans", "Interface\\AddOns\\XayaUI\\Media\\Fonts\\PT_Sans-Web-Regular.ttf" },
    barlow = { "Barlow", "Interface\\AddOns\\XayaUI\\Media\\Fonts\\Barlow-Regular.ttf" },
    firamono = { "Fira Mono", "Interface\\AddOns\\XayaUI\\Media\\Fonts\\FiraMono-Regular.ttf" },
}
local BUILTIN_FONT_ORDER = { "frizqt", "arialn", "skurri", "morpheus", "firasans", "lato", "ptsans", "barlow", "firamono" }
function ns.FontList()
    local values, order = { none = "(none - game default)" }, { "none" }
    for _, k in ipairs(BUILTIN_FONT_ORDER) do values[k] = BUILTIN_FONTS[k][1]; order[#order + 1] = k end
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    if lsm then
        local names = {}
        for n in pairs(lsm:HashTable("font")) do names[#names + 1] = n end
        table.sort(names)
        for _, n in ipairs(names) do values["lsm:" .. n] = n; order[#order + 1] = "lsm:" .. n end
    end
    return values, order
end
function ns.FontPath(key)
    key = ns.Val(key)
    if key then
        if BUILTIN_FONTS[key] then return BUILTIN_FONTS[key][2] end
        local n = key:match("^lsm:(.+)$")
        local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
        local p = n and lsm and lsm:Fetch("font", n, true)
        if p then return p end
    end
    return STANDARD_TEXT_FONT
end

function ns.NewRule()
    local r = Copy(ns.RULE_DEFAULTS)
    return r
end

ns.Merge = Merge

-- Bring a rule table (saved or imported) up to the current shape.
function ns.NormalizeRule(r)
    -- migrate v0.1/0.2 flat context fields into r.load
    if type(r.load) ~= "table" then r.load = {} end
    for _, k in ipairs({ "combat", "group", "instance" }) do
        if r[k] ~= nil then r.load[k] = r[k]; r[k] = nil end
    end
    Merge(r, ns.RULE_DEFAULTS)
    if ns.NormalizeExtra then ns.NormalizeExtra(r) end
    if ns.NormalizeWhen then ns.NormalizeWhen(r) end
    if ns.NormalizeCues then ns.NormalizeCues(r) end
    if ns.NormalizeActions then ns.NormalizeActions(r) end
    -- legacy "any" -> "none" (explicit "ignore")
    for _, k in ipairs({ "cdState", "buffState", "talentState" }) do if r[k] == "any" then r[k] = "none" end end
    -- built-in Buff / Aura "seconds left" (0.6.4): a comparison and a number, or nothing
    if not (r.buffTimeOp == ">=" or r.buffTimeOp == "<=" or r.buffTimeOp == ">" or r.buffTimeOp == "<") then r.buffTimeOp = nil end
    if r.buffTimeSec ~= nil then r.buffTimeSec = tonumber(r.buffTimeSec) end
    for k, v in pairs(r.load) do if v == "any" and k ~= "mode" then r.load[k] = "none" end end
    -- talents: single talentID/talentState -> list + mode
    if type(r.talents) ~= "table" then r.talents = {} end
    if r.talentID ~= nil or r.talentState ~= nil then
        local ts = r.talentState
        if (r.talentID or 0) ~= 0 and (ts == "known" or ts == "notKnown") then
            if #r.talents == 0 then r.talents[1] = { id = r.talentID, state = ts } end
            r.talentMode = r.talentMode or "all"
        elseif ts == "none" or ts == "any" or ts == "known" or ts == "notKnown" then
            r.talentMode = r.talentMode or "none"
        end
        r.talentID, r.talentState = nil, nil
    end
end

local function InitDB()
    CueRulesDB = CueRulesDB or {}
    CueRulesDB.rules = CueRulesDB.rules or {}
    CueRulesDB.version = CueRulesDB.version or 1
    CueRulesDB.ui = CueRulesDB.ui or {}
    if CueRulesDB.ui.trayOpen == nil then CueRulesDB.ui.trayOpen = true end
    -- Advanced Debugging defaults ON (recommended): XayaUI's own Lua errors print to chat as a system message.
    if CueRulesDB.ui.advancedDebug == nil then CueRulesDB.ui.advancedDebug = true end
    for _, r in ipairs(CueRulesDB.rules) do ns.NormalizeRule(r) end
    ns.rules = CueRulesDB.rules
    if ns.MigrateCues then
        local ok, n = pcall(ns.MigrateCues)
        if not ok and ns.RecordError then pcall(ns.RecordError, "XayaUI cue migration: " .. tostring(n), nil, "XayaUI", "XUI-E011") end   -- (audit D57)
        if ok and n and n > 0 then ns.Print(n .. " existing sounds / displays were moved into Cues (each condition now lists them under THEN; a full backup of your rules was saved first).") end
    end
    CueRulesDB.qol = CueRulesDB.qol or {}
    CueRulesDB.qol.boxes = CueRulesDB.qol.boxes or {}
    for _, b in ipairs(CueRulesDB.qol.boxes) do
        Merge(b, ns.QOL_BOX_DEFAULTS)
        if b.showCombat == "any" then b.showCombat = "none" end
    end
    ns.qolBoxes = CueRulesDB.qol.boxes
    CueRulesDB.folders = CueRulesDB.folders or {}
    ns.folders = CueRulesDB.folders
    ns.EnsureDefaultFolders()
    do   -- group ids must be "f" + digits (the tree, previews and menus find groups by that form); an import once kept ids like "feui1"
        local n = ns.FixFolderIds and ns.FixFolderIds()
        if n and n > 0 then ns.Print(n .. " imported group(s) were given standard ids so they can be previewed, renamed, and moved.") end
    end
    local nHyb = ns.MigrateToHybrid()
    if nHyb and nHyb > 0 then ns.Print(nHyb .. " existing rules are now under Hybrid Cues (they keep both their display and sound options).") end
    local nProg = ns.MigrateToProgress()
    if nProg and nProg > 0 then ns.Print(nProg .. " active display(s) were converted to progress textures (base and overlay wipe together).") end
    CueRulesDB.bars = CueRulesDB.bars or {}
    for _, b in ipairs(CueRulesDB.bars) do Merge(b, ns.BAR_DEFAULTS) end
    ns.bars = CueRulesDB.bars
    CueRulesDB.barGroup = CueRulesDB.barGroup or {}
    Merge(CueRulesDB.barGroup, ns.BAR_GROUP_DEFAULTS)
    ns.barGroup = CueRulesDB.barGroup
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")   -- (Modules.lua ns.AtLogin: one frame for every feature that waits for the login; let go once fired)
f:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" then
        f:UnregisterEvent("PLAYER_LOGIN")
        if ns.FireLogin then ns.FireLogin() end
        return
    end
    if name ~= addonName then return end
    InitDB()
    f:UnregisterEvent("ADDON_LOADED")
    if ns.OnDBReady then ns.OnDBReady() end   -- the rule engine first (Engine.lua)
    ns.FireReady()                            -- then every feature that asked through ns.WhenReady (Modules.lua), in load order
end)

-------------------------------------------------------------------------------
-- Slash commands
-- core 0.6.50 (Xaya 2026-11-05: "can't some of these be consolidated into a /xui debug _____ ? this is a LOT of noise"): /xui help
-- lists only what a player uses (16 lines, was 29); the diagnostic commands are under /xui debug <name>, and /xui debug alone lists
-- them. Their old forms (/xui perf ...) no longer run (Xaya 2026-11-06: "let's move to /xui debug ____", "7. Retire"): an unknown
-- word prints /xui help. Xaya's answers of 2026-11-06 (request log row 7): any /xui debug command opens the console window and prints
-- there ("Debug cmds open console"); /xui status and /xui auras stay as shortcuts that print in chat ("Debug + shortcut", "/xui auras
-- prints to chat instead", status "Yes, same as auras"); the old /xui debug (can the settings window load) is /xui debug loader.
-------------------------------------------------------------------------------
-- the diagnostic commands core owns: { name, fn(arg), help }. help is "name [args] (what it does)", without "/xui debug".
-- core 0.6.56 (Xaya 2026-11-06, REQUEST-LOG #81, her answers: developer diagnostics "Move all of them"; edge cases "Yes, as
-- recommended"): only these stay in core for players: status (the console form of /xui status), perf (the engine meter; "perf ui" is
-- XayaUI Dev Assist's), talents (rule creation uses the scan) and loader (for when /xui will not open the window). auras is AuraList.lua's.
-- Every other diagnostic (probe, timing, model, tracker, mods, groups, icons, media, seed, map, debuffs, loc, gamemenu, chatprobe,
-- widthprobe, perf ui) is registered by XayaUI Dev Assist (XayaUI_DevAssist/CoreDebug.lua); without it they and their help lines do
-- not exist, and core does not load their code.
local CORE_DEBUG = {
    { "status", function() if ns.PrintStatus then ns.PrintStatus() end end, "status (every rule's answer right now, and why)" },
    { "perf", function(arg)
        if tostring(arg or ""):lower():match("^ui") then   -- settings-window rebuild timing: XayaUI Dev Assist's (it registers "perf")
            if not (ns.RunDebugCommand and ns.RunDebugCommand("perf", arg)) then
                ns.Print(("there is no debug command \"perf %s\"."):format((tostring(arg):gsub("|", "||"))))
                ns.PrintDebugHelp()
            end
        elseif ns.PerfCommand then ns.PerfCommand(arg) end   -- engine timing on this machine (Engine.lua)
    end, "perf [on|off] (engine timing)" },
    { "talents", function(arg) if ns.TalentCommand then ns.TalentCommand(arg) end end, "talents [status|<name>] (scan every class's talents; find one by name)" },
    { "loader", function()   -- (was /xui debug window; Xaya 2026-11-06: "Rename it" -> "/xui debug loader")
        local function yn(v) return v and "yes" or "NO" end
        ns.Print(("debug: ToggleUI=%s rules=%s AceConfigDialog=%s AceConfigRegistry=%s AceGUI=%s"):format(
            yn(ns.ToggleUI), yn(ns.rules), yn(LibStub and LibStub("AceConfigDialog-3.0", true)),
            yn(LibStub and LibStub("AceConfigRegistry-3.0", true)), yn(LibStub and LibStub("AceGUI-3.0", true))))
        ns.Print("debug: settings window " .. (ns.Options and "loaded" or ("not loaded yet (" .. ns.ModuleState(ns.OPTIONS_ADDON) .. ")")))
    end, "loader (whether the settings window's code can load)" },
}
local coreDebug = {}
for _, d in ipairs(CORE_DEBUG) do coreDebug[d[1]] = d[2] end

-- the player's commands core owns (/xui help); features add theirs through ns.RegisterCommand (Modules.lua)
local CORE_HELP = { "/xui (settings)", "/xui console (the XayaUI console: its messages, and a line to type these commands in)",
    "/xui bug (bug report)", "/xui report (debug report: XayaUI's errors and warnings with their codes, to send to Xaya)",
    "/xui unlock (drag displays and groups; again to lock)",
    "/xui status (every rule's answer right now, and why; in chat)",
    "/xui auras [target|focus|pet] [debuffs] or <spellID> (aura IDs, and whether XayaUI can follow them in combat; in chat)",
    "/xui debug (diagnostic commands, shown in the console window: lists them)" }

-- one command per line (core 0.6.46; Xaya 2026-11-05: "console print is difficult to read"): the command in the theme's accent text
-- color, what it does after it. An entry that holds two commands (" | /xui ...") is split. Pipes in the text (option lists such as
-- [on|off]) are doubled ("||"), which the game shows as one "|" (Xaya 2026-11-06 chose "Back to '|'" over "[on/off]"; the chat history
-- window, which lost a "|" and the letter after it, shows them right since Chat 0.6.17).
local function PrintCommandList(header, list, prefix)
    local items = {}
    for _, h in ipairs(list) do
        local rest = h
        while true do
            local a = rest:find(" | /xui", 1, true)
            if not a then items[#items + 1] = rest; break end
            items[#items + 1] = rest:sub(1, a - 1); rest = rest:sub(a + 3)
        end
    end
    local c = (ns.Theme and ns.Theme.cur and ns.Theme.cur.accentText) or { 0.78, 0.62, 1 }
    local hex = ("|cff%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
    ns.Print(header:format(#items))
    for _, h in ipairs(items) do
        local cmdText, desc = h:match("^(.-)%s*(%b())$")
        if not cmdText or cmdText == "" then cmdText, desc = h, nil end
        local line = "  " .. hex .. (prefix or "") .. (cmdText:gsub("|", "||")) .. "|r"
        if desc then line = line .. "  " .. (desc:sub(2, -2):gsub("|", "||")) end
        ns.Print(line)
    end
end
function ns.PrintHelp()
    local help = {}
    for _, h in ipairs(CORE_HELP) do help[#help + 1] = h end
    for _, h in ipairs(ns.CommandHelp()) do help[#help + 1] = h end
    PrintCommandList("commands (%d):", help)
end
function ns.PrintDebugHelp()
    local help = {}
    for _, d in ipairs(CORE_DEBUG) do
        for _, h in ipairs(type(d[3]) == "table" and d[3] or { d[3] }) do help[#help + 1] = h end
    end
    for _, h in ipairs(ns.DebugCommandHelp and ns.DebugCommandHelp() or {}) do help[#help + 1] = h end
    PrintCommandList("debug commands (%d), each typed as /xui debug <name>:", help, "/xui debug ")
end
-- /xui debug <name> [args]
local function RunDebug(arg)
    local sub, rest = tostring(arg or ""):match("^(%S*)%s*(.-)$")
    if sub == "" or sub == "help" then ns.PrintDebugHelp()
    elseif coreDebug[sub] then coreDebug[sub](rest)
    elseif ns.RunDebugCommand and ns.RunDebugCommand(sub, rest) then   -- a feature's own (Modules.lua ns.RegisterDebugCommand)
    elseif ns.ModuleMissingText(sub, true) then ns.Print(ns.ModuleMissingText(sub, true))   -- a feature's, whose addon is off
    else
        ns.Print(("there is no debug command \"%s\"."):format((sub:gsub("|", "||"))))
        ns.PrintDebugHelp()
    end
end

-- /xui status and /xui auras: their /xui debug command, printed in chat (Xaya 2026-11-06). An error goes to the game's error handler
-- with ns.chatRunning still set, then it is cleared.
local SHORTCUTS = { status = true, auras = true }
local function RunInChat(fn, ...)
    local prev, args, n = ns.chatRunning, { ... }, select("#", ...)
    ns.chatRunning = true
    xpcall(function() fn(unpack(args, 1, n)) end, function(e) local h = geterrorhandler and geterrorhandler(); if h then pcall(h, e) end end)
    ns.chatRunning = prev
end
local function RunShortcut(name, arg)
    if coreDebug[name] then coreDebug[name](arg)
    elseif not (ns.RunDebugCommand and ns.RunDebugCommand(name, arg)) then ns.PrintHelp() end
end

SLASH_XAYAUI1 = "/xui"
SLASH_XAYAUI2 = "/xayaui"
SlashCmdList["XAYAUI"] = function(msg)
    msg = (msg or ""):lower()
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    if cmd == "" or cmd == "config" or cmd == "options" then
        ns.ToggleUI()   -- loads XayaUI_Options on first use (Modules.lua section 7)
    elseif cmd == "debug" then
        -- (Xaya 2026-11-06: "Debug cmds open console") opens the console window and prints there; Console.lua ns.RunInConsole
        if ns.RunInConsole then ns.RunInConsole(true, RunDebug, arg) else RunDebug(arg) end
    elseif SHORTCUTS[cmd] then
        RunInChat(RunShortcut, cmd, arg)
    elseif cmd == "unlock" then
        if ns.ToggleUnlock then ns.ToggleUnlock() end
    elseif cmd == "console" then
        if ns.ConsoleWindow then ns.ConsoleWindow() end
    elseif cmd == "bug" then
        if ns.ShowBugReport then ns.ShowBugReport() end
    elseif cmd == "report" then   -- (core 0.6.56; REQUEST-LOG #82: the debug report window, DebugRecord.lua)
        if ns.ShowDebugReport then ns.ShowDebugReport() end
    elseif ns.RunCommand(cmd, arg) then   -- a feature's own command (Modules.lua: ns.RegisterCommand)
    elseif ns.ModuleMissingText(cmd) then   -- a feature's command whose addon is off or failed to load
        ns.Print(ns.ModuleMissingText(cmd))
    else
        ns.PrintHelp()
    end
end
