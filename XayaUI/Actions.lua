-- XayaUI: Actions. The things a rule DOES (as opposed to Cues, which are things it shows / plays) at three moments, modeled on the
-- Actions tab: On Initialization (the rule loads), During (the rule starts), After It Ends (the rule stops).
-- Each moment can send a chat message, glow a frame and run custom code; "During" also has the rule's sound (with repeat), "After" a sound.
-- Storage: rule.actions = { init = {...}, start = {...}, finish = {...} }
--   msgOn, msgType (PRINT|ERROR|TTS|SAY|YELL|GROUP), msg, glowOn, glowTarget ("self"|"frame"), glowFrame, glowType, glowR/G/B/A,
--   glowX / glowY (offset; not the button glow), glowLevel (frame level), and per glow type: pixN, pixFreq, pixLen, pixTh, pixBorder;
--   acN, acFreq, acScale; btnFreq; procDur, procStart. A setting left empty (nil) uses LibCustomGlow's own default.
--   glowKeep (start only), snd (finish only, same shape as rule.sound), codeOn, code.
-- Midnight (12.x) notes are in the option descriptions; see the design doc for sources.
local addonName, ns = ...

ns.ACTION_PHASES = { "init", "start", "finish" }
local CHAT_TYPES = {
    PRINT = "Print to my chat window (only I see it)",
    ERROR = "Red text in the middle of the screen (only I see it)",
    TTS = "Read aloud (text-to-speech)",
    SAY = "Say (only works inside instances)",
    YELL = "Yell (only works inside instances)",
    GROUP = "Group chat (instance / raid / party, whichever applies)",
}
local CHAT_ORDER = { "PRINT", "ERROR", "TTS", "SAY", "YELL", "GROUP" }
local GLOW_TYPES = { button = "Button glow (gold border)", pixel = "Pixel glow (moving lines)", autocast = "Autocast shine (sparkles)", proc = "Proc glow (spell alert)" }
local GLOW_ORDER = { "button", "pixel", "autocast", "proc" }
local GLOW_KEY = "XayaUI"

local function LCG() return LibStub and LibStub("LibCustomGlow-1.0", true) or nil end

-- LibCustomGlow-1.0's four glow types and the settings each accepts (read in its public source, MINOR 25, 2026-11-04; defaults are the
-- library's own and apply whenever XayaUI passes nil):
--   PixelGlow_Start(frame, color, N lines = 8, frequency = 0.25 (negative: reverse), length = auto, thickness = 1, xOffset, yOffset,
--                   border (on unless false), key, frameLevel = 8)
--   AutoCastGlow_Start(frame, color, N groups = 4, frequency = 0.125 (negative: reverse), scale = 1, xOffset, yOffset, key, frameLevel)
--   ButtonGlow_Start(frame, color, frequency (> 0 only; the speed of its moving border, default = 0.25), frameLevel)   -- no offset
--   ProcGlow_Start(frame, { color, startAnim = true, xOffset, yOffset, duration = 1, key, frameLevel })
-- Alpha: pixel, autocast and proc glows use color[4] in SetVertexColor; the button glow uses it in its alpha animation.
-- The copy loaded in game comes from another addon (ElvUI, BigWigs ...); an older copy may differ (not checked).
-- name, min, max, step, default (the library's own default, shown when nothing is saved)
local GLOW_NUM = {
    glowX = { -40, 40, 1, 0 }, glowY = { -40, 40, 1, 0 }, glowLevel = { 1, 50, 1, 8 },
    pixN = { 1, 30, 1, 8 }, pixFreq = { -2, 2, 0.05, 0.25 }, pixLen = { 0, 60, 1, 0 }, pixTh = { 1, 10, 1, 1 },
    acN = { 1, 12, 1, 4 }, acFreq = { -2, 2, 0.05, 0.125 }, acScale = { 0.2, 3, 0.05, 1 },
    btnFreq = { 0, 2, 0.05, 0 }, procDur = { 0.1, 5, 0.1, 1 },
}
-- a saved number inside its range, else nil (= the library's default); a damaged saved value never reaches the library
local function GN(a, k)
    local v, d = a[k], GLOW_NUM[k]
    if type(v) ~= "number" or v ~= v or not d then return nil end
    if v < d[1] then v = d[1] elseif v > d[2] then v = d[2] end
    return v
end

function ns.ActionsOf(rule, phase)
    if type(rule.actions) ~= "table" then rule.actions = {} end
    if type(rule.actions[phase]) ~= "table" then rule.actions[phase] = {} end
    return rule.actions[phase]
end
local function Existing(rule, phase) return rule.actions and rule.actions[phase] end

-- Sanitize what comes from saved data / imports (called from NormalizeRule). Custom code is NEVER kept from an import (see Profile.lua).
function ns.NormalizeActions(r)
    if type(r.actions) ~= "table" then r.actions = nil; return end
    local keep
    for _, ph in ipairs(ns.ACTION_PHASES) do
        local a = r.actions[ph]
        if type(a) == "table" then
            if not CHAT_TYPES[a.msgType] then a.msgType = "PRINT" end
            a.msg = (type(a.msg) == "string") and a.msg:sub(1, 255) or nil
            a.code = (type(a.code) == "string") and a.code:sub(1, 8000) or nil
            a.glowFrame = (type(a.glowFrame) == "string") and a.glowFrame:sub(1, 80) or nil
            if not GLOW_TYPES[a.glowType] then a.glowType = "button" end
            keep = true
        else r.actions[ph] = nil end
    end
    if not keep then r.actions = nil end
end

-- Placeholders: %n rule name, %s spell name, %b buff name. (Numbers from combat are secret in Midnight, so there are none here.)
local function Fill(rule, text)
    text = tostring(text or "")
    if not text:find("%", 1, true) then return text end
    local function nm(id) if (tonumber(id) or 0) > 0 and C_Spell and C_Spell.GetSpellName then local ok, n = pcall(C_Spell.GetSpellName, id); if ok and n then return n end end return "" end
    text = text:gsub("%%n", function() return tostring(rule.name or "") end)
    text = text:gsub("%%s", function() return nm(rule.spellID) end)
    text = text:gsub("%%b", function() return nm(rule.buffID) end)
    return text
end

local function DoChat(rule, a)
    local msg = Fill(rule, a.msg)
    if msg == "" then return end
    local t = a.msgType or "PRINT"
    if t == "PRINT" then
        DEFAULT_CHAT_FRAME:AddMessage(msg, a.msgR or 1, a.msgG or 1, a.msgB or 1)
    elseif t == "ERROR" then
        if UIErrorsFrame then UIErrorsFrame:AddMessage(msg, 1, 0.1, 0.1) end
    elseif t == "TTS" then
        -- Through the speech cue's own helper (Sound.lua ns.Speak), which uses the 12.x signature
        -- C_VoiceChat.SpeakText(voiceID, text, rate, volume [, overlap]) (docs/reference/api/namespaces.md:5450). This line used the old one,
        -- (voiceID, text, destination, rate, volume): Enum.VoiceTtsDestination is gone in 12.1.5 (not in enums.md), so it passed rate 1
        -- and volume 0, and an action's speech was silent. The voice: the game's own Standard text-to-speech voice when it is installed.
        pcall(function()
            local vid
            if C_TTSSettings and C_TTSSettings.GetVoiceOptionID and Enum and Enum.TtsVoiceType then
                local ok, v = pcall(C_TTSSettings.GetVoiceOptionID, Enum.TtsVoiceType.Standard)
                if ok and type(v) == "number" and not (issecretvalue and issecretvalue(v)) then vid = v end
            end
            if ns.Speak then ns.Speak({ value = msg, voice = vid, rate = 0, ttsVolume = 100 }) end
        end)
    elseif t == "SAY" or t == "YELL" then
        if IsInInstance() then pcall(ns.Compat.SendChatMessage, msg, t) end
    elseif t == "GROUP" then
        local ch
        if UnitInBattleground and UnitInBattleground("player") then ch = "INSTANCE_CHAT"
        elseif IsInRaid() then ch = (IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT") or "RAID"
        elseif IsInGroup() then ch = (IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT") or "PARTY" end
        if ch then pcall(ns.Compat.SendChatMessage, msg, ch) end
    end
end

local function GlowTargets(rule, a)
    local out = {}
    if a.glowTarget == "frame" then
        local f = a.glowFrame and a.glowFrame ~= "" and _G[a.glowFrame]
        if type(f) == "table" and f.GetObjectType then out[1] = f end
    elseif ns.VisualFramesOf then
        for _, f in ipairs(ns.VisualFramesOf(rule)) do out[#out + 1] = f end
    end
    return out
end
local function GlowStop(rule, a)
    local lib = LCG()
    if not lib then return end
    for _, f in ipairs(GlowTargets(rule, a)) do
        pcall(lib.PixelGlow_Stop, f, GLOW_KEY); pcall(lib.AutoCastGlow_Stop, f, GLOW_KEY)
        pcall(lib.ButtonGlow_Stop, f); pcall(lib.ProcGlow_Stop, f, GLOW_KEY)
    end
end
local function GlowStart(rule, a)
    local lib = LCG()
    if not lib then
        if not ns.glowWarned then ns.glowWarned = true; ns.Print("glow actions need the LibCustomGlow library, which comes with other addons (ElvUI, BigWigs, and others). None is loaded right now.") end
        return
    end
    local alpha = a.glowA
    if type(alpha) ~= "number" or alpha ~= alpha then alpha = 1 elseif alpha < 0 then alpha = 0 elseif alpha > 1 then alpha = 1 end
    local col = { a.glowR or 0.95, a.glowG or 0.95, a.glowB or 0.32, alpha }
    local x, y, lvl = GN(a, "glowX"), GN(a, "glowY"), GN(a, "glowLevel")
    for _, f in ipairs(GlowTargets(rule, a)) do
        local t = a.glowType
        if t == "pixel" then
            local len = GN(a, "pixLen"); if len == 0 then len = nil end   -- 0 = the library works the length out from the frame
            local freq = GN(a, "pixFreq"); if freq == 0 then freq = nil end
            local border = nil; if a.pixBorder == false then border = false end   -- nil = the library's default (border on)
            pcall(lib.PixelGlow_Start, f, col, GN(a, "pixN"), freq, len, GN(a, "pixTh"), x, y, border, GLOW_KEY, lvl)
        elseif t == "autocast" then
            local freq = GN(a, "acFreq"); if freq == 0 then freq = nil end
            pcall(lib.AutoCastGlow_Start, f, col, GN(a, "acN"), freq, GN(a, "acScale"), x, y, GLOW_KEY, lvl)
        elseif t == "proc" then
            local opts = { color = col, key = GLOW_KEY, xOffset = x, yOffset = y, duration = GN(a, "procDur"), frameLevel = lvl }
            if a.procStart == false then opts.startAnim = false end   -- left out = the library's default (start flash on)
            pcall(lib.ProcGlow_Start, f, opts)
        else
            local freq = GN(a, "btnFreq"); if freq == 0 then freq = nil end
            pcall(lib.ButtonGlow_Start, f, col, freq, lvl)
        end
    end
end

-- Custom code runs only when that moment's own "Run custom code" box is ticked (there is no all-rules switch any more). Profile.lua strips code and
-- codeOn from every import, so a box can only ever be ticked, and code only ever written, by you.
local function DoCode(rule, phase, a)
    local fn, err = loadstring(a.code, "XayaUI action: " .. tostring(rule.name))
    if not fn then ns.Print("custom code error in '" .. tostring(rule.name) .. "' (" .. phase .. "): " .. tostring(err)); return end
    local ok, e = pcall(fn, rule)
    if not ok then ns.Print("custom code error in '" .. tostring(rule.name) .. "' (" .. phase .. "): " .. tostring(e)) end
end

-- phase: "init" | "start" | "finish". Called by the engine; never for cues / conditions.
function ns.RunActions(rule, phase)
    if rule.parentUid then return end
    local a = Existing(rule, phase)
    if phase == "finish" then
        local s = Existing(rule, "start")
        if s and s.glowOn and not s.glowKeep then GlowStop(rule, s) end
    end
    if not a then return end
    if a.msgOn and a.msg and a.msg ~= "" then pcall(DoChat, rule, a) end
    if phase == "finish" and a.snd and a.snd.enabled then pcall(ns.PlaySound, a.snd) end
    if a.glowOn and phase ~= "finish" then pcall(GlowStart, rule, a) end
    if phase == "finish" and a.glowOn then pcall(GlowStop, rule, a) end   -- an explicit "stop glow" after the end
    if a.codeOn and a.code and a.code ~= "" then DoCode(rule, phase, a) end
end

-------------------------------------------------------------------------------
-- The Actions tab (built by Options.lua through ns.ActionsPane)
-------------------------------------------------------------------------------
function ns.ActionsPane(rule, Notify, extra)
    extra = extra or {}
    local function get(phase, k) local a = Existing(rule, phase); return a and a[k] end
    local function put(phase, k, v) ns.ActionsOf(rule, phase)[k] = v; ns.MarkDirty() end
    local function On(phase, k) return function() return get(phase, k) and true or false end end
    local function Off(phase, k) return function() return not get(phase, k) end end

    local function Phase(phase, title, order, blurb)
        local args = {
            blurb = { type = "description", order = 0, width = "full", fontSize = "small", name = blurb },
            -- chat -------------------------------------------------------
            msgOn = { type = "toggle", order = 10, width = "full", name = "Send a chat message",
                get = On(phase, "msgOn"), set = function(_, v) put(phase, "msgOn", v and true or nil); Notify() end },
            msgType = { type = "select", order = 11, width = "double", name = "Message type", values = CHAT_TYPES, sorting = CHAT_ORDER,
                hidden = Off(phase, "msgOn"),
                desc = "Print, red text, and read-aloud only ever reach you. Say / Yell / Group send to other players: WoW blocks automated messages to Say and Yell outside instances, and in Midnight addons cannot send chat during a Mythic+ run, a PvP match, or a boss encounter (alpha notes; not re-checked on the live client).",
                get = function() return get(phase, "msgType") or "PRINT" end, set = function(_, v) put(phase, "msgType", v) end },
            msg = { type = "input", order = 12, width = "full", name = "Message  (%n = rule name, %s = spell name, %b = buff name)",
                hidden = Off(phase, "msgOn"),
                get = function() return get(phase, "msg") or "" end, set = function(_, v) put(phase, "msg", (v ~= "") and v:sub(1, 255) or nil) end },
            -- glow -------------------------------------------------------
            glowOn = { type = "toggle", order = 20, width = "full",
                name = (phase == "finish") and "Stop a glow on a frame" or "Glow a frame",
                desc = "Uses the LibCustomGlow library that other addons, such as ElvUI and BigWigs, install. If none of them is loaded there is nothing to glow with.",
                get = On(phase, "glowOn"), set = function(_, v) put(phase, "glowOn", v and true or nil); Notify() end },
            glowTarget = { type = "select", order = 21, width = "double", name = "Glow",
                values = { self = "This rule's own display (and its cues)", frame = "Another frame (type its name)" }, sorting = { "self", "frame" },
                hidden = Off(phase, "glowOn"),
                get = function() return get(phase, "glowTarget") or "self" end, set = function(_, v) put(phase, "glowTarget", v); Notify() end },
            glowFrame = { type = "input", order = 22, width = "double", name = "Frame name",
                desc = "The global name of any frame, e.g. PlayerFrame or ActionButton1. Frame names from other addons work too.",
                hidden = function() return not get(phase, "glowOn") or get(phase, "glowTarget") ~= "frame" end,
                get = function() return get(phase, "glowFrame") or "" end, set = function(_, v) put(phase, "glowFrame", (v ~= "") and v or nil) end },
            glowType = { type = "select", order = 23, width = "double", name = "Glow type", values = GLOW_TYPES, sorting = GLOW_ORDER,
                hidden = function() return phase == "finish" or not get(phase, "glowOn") end,
                get = function() return get(phase, "glowType") or "button" end, set = function(_, v) put(phase, "glowType", v) end },
            glowColor = { type = "color", order = 24, width = "half", name = "Color", hasAlpha = true,
                desc = "The glow's color and opacity (the picker's opacity slider).",
                hidden = function() return phase == "finish" or not get(phase, "glowOn") end,
                get = function()
                    local al = get(phase, "glowA")
                    return get(phase, "glowR") or 0.95, get(phase, "glowG") or 0.95, get(phase, "glowB") or 0.32, (type(al) == "number") and al or 1
                end,
                set = function(_, r, g, b, al)
                    put(phase, "glowR", r); put(phase, "glowG", g); put(phase, "glowB", b)
                    put(phase, "glowA", (type(al) == "number" and al < 1) and al or nil)   -- fully opaque is the default: nothing kept
                end },
            -- code -------------------------------------------------------
            codeOn = { type = "toggle", order = 40, width = "full", name = "Run custom code",
                desc = "Lua that runs as you, at this moment only. It is never kept when you import a profile, so you only ever run code you typed or pasted in yourself. In Midnight, combat numbers are secret values: code that reads or compares them errors.",
                get = On(phase, "codeOn"), set = function(_, v) put(phase, "codeOn", v and true or nil); Notify() end },
            code = { type = "input", multiline = 8, order = 41, width = "full", name = "Code  (the rule is passed in as ...)",
                hidden = Off(phase, "codeOn"),
                get = function() return get(phase, "code") or "" end, set = function(_, v) put(phase, "code", (v ~= "") and v:sub(1, 8000) or nil) end },
        }
        -- the glow type's own settings (shown only for the type that uses them; empty = the library's default)
        if phase ~= "finish" then
            local function typeIs(...)
                local want = { ... }
                return function()
                    if not get(phase, "glowOn") then return false end
                    local t = get(phase, "glowType") or "button"
                    for _, w in ipairs(want) do if w == t then return true end end
                    return false
                end
            end
            local ZERO_IS_DEFAULT = { pixFreq = true, acFreq = true, pixLen = true, btnFreq = true }
            local function Num(key, order, name, desc, shown, pct)
                local d = GLOW_NUM[key]
                return { type = "range", order = order, width = "normal", name = name, desc = desc, min = d[1], max = d[2], step = d[3],
                    isPercent = pct, hidden = function() return not shown() end,
                    get = function() local v = get(phase, key); return (type(v) == "number") and v or d[4] end,
                    set = function(_, v)
                        if v == d[4] or (v == 0 and ZERO_IS_DEFAULT[key]) then put(phase, key, nil) else put(phase, key, v) end
                    end }
            end
            local moved, pix, ac, btn, proc = typeIs("pixel", "autocast", "proc"), typeIs("pixel"), typeIs("autocast"), typeIs("button"), typeIs("proc")
            args.glowX = Num("glowX", 24.1, "Offset X", "Moves the glow left (negative) or right, in pixels. The button glow cannot be moved.", moved)
            args.glowY = Num("glowY", 24.2, "Offset Y", "Moves the glow down (negative) or up, in pixels. The button glow cannot be moved.", moved)
            args.glowLevel = Num("glowLevel", 24.3, "Layer", "Frame level of the glow: higher draws above more of the frame's own parts. Default 8.",
                typeIs("button", "pixel", "autocast", "proc"))
            args.pixN = Num("pixN", 24.4, "Lines", "How many moving lines. Default 8.", pix)
            args.pixFreq = Num("pixFreq", 24.5, "Speed", "Laps per second. Negative runs the lines the other way; 0 = default (0.25).", pix)
            args.pixLen = Num("pixLen", 24.6, "Line length", "Length of each line in pixels; 0 = worked out from the frame's size.", pix)
            args.pixTh = Num("pixTh", 24.7, "Thickness", "Line thickness in pixels. Default 1.", pix)
            args.pixBorder = { type = "toggle", order = 24.8, width = "normal", name = "Dark border",
                desc = "A dark border under the lines (on by default).", hidden = function() return not pix() end,
                get = function() return get(phase, "pixBorder") ~= false end,
                set = function(_, v) if v then put(phase, "pixBorder", nil) else put(phase, "pixBorder", false) end end }
            args.acN = Num("acN", 24.4, "Sparkle groups", "How many groups of sparkles circle the frame. Default 4.", ac)
            args.acFreq = Num("acFreq", 24.5, "Speed", "Laps per second. Negative turns the other way; 0 = default (0.125).", ac)
            args.acScale = Num("acScale", 24.6, "Sparkle size", "Size of the sparkles. Default 1 (100%).", ac, true)
            args.btnFreq = Num("btnFreq", 24.4, "Speed", "Speed of the moving border: higher is faster; 0 = default (same as 0.25).", btn)
            args.procDur = Num("procDur", 24.4, "Loop length", "Seconds per loop of the spell-alert animation. Default 1.", proc)
            args.procStart = { type = "toggle", order = 24.5, width = "normal", name = "Start flash",
                desc = "Play the spell alert's opening flash before the loop (on by default).", hidden = function() return not proc() end,
                get = function() return get(phase, "procStart") ~= false end,
                set = function(_, v) if v then put(phase, "procStart", nil) else put(phase, "procStart", false) end end }
        end
        if phase == "start" then
            args.glowKeep = { type = "toggle", order = 25, width = "full", name = "Keep glowing after the rule ends",
                hidden = Off(phase, "glowOn"),
                desc = "Off: the glow is removed when the rule stops.",
                get = function() return get(phase, "glowKeep") and true or false end, set = function(_, v) put(phase, "glowKeep", v and true or nil) end }
            if extra.sound then args.sound = extra.sound; args.sound.order = 30 end
        elseif phase == "finish" and extra.finishSound then
            local snd = extra.finishSound(function() return ns.ActionsOf(rule, "finish") end)
            for key, node in pairs(snd.args) do
                args["snd_" .. key] = node
                node.order = 30 + (tonumber(node.order) or 0) / 100
            end
        end
        return { type = "group", inline = true, order = order, name = title, args = args }
    end

    local args = {
        intro = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "What the rule does at three moments. What it shows or plays as a result of conditions is set on the Cues tab." },
        init = Phase("init", "On Initialization", 1, "Runs once when the rule loads: after a /reload or login, a spec change, or when its load conditions become true."),
        start = Phase("start", "During", 2, "Runs when the rule starts (its trigger becomes true)."),
        finish = Phase("finish", "After It Ends", 3, "Runs when the rule stops (its trigger becomes false)."),
    }
    return args
end
