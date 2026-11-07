-------------------------------------------------------------------------------
-- Chat/Probe.lua : /xui debug chatprobe. Stage S0 of the Chat Panel rebuild.
-- READ ONLY. It never moves, hides, shows, re-parents or styles anything. It looks at Blizzard's chat as it is right now and writes
-- what it finds to CueRulesDB.chatProbe (saved when you /reload or log out), so the rebuild is built on the real frame names and
-- anchors instead of guesses. It also prints the frames sitting in the top-left corner of the screen (to name the floating button).
-- Privacy: message TEXT is never written. Only whether a message is readable ("secret") and how long it is.
-- Own code, written from the documented game API only. UNTESTED in game.
-------------------------------------------------------------------------------
-- (Dev Assist 0.7.5: moved here from XayaUI_Chat/Probe.lua; REQUEST-LOG #81, Xaya 2026-11-06: "Move all of them". Unchanged otherwise.)
local ns = rawget(_G, "XayaUI_NS")   -- XayaUI core's namespace; without XayaUI there is nothing to register into
if type(ns) ~= "table" or type(ns.RegisterDebugCommand) ~= "function" then return end

local MAX_LINES = 1400
local lines

local function secret(v) return issecretvalue and issecretvalue(v) or false end

local function try(f, ...)
    local ok, a, b, c, d, e = pcall(f, ...)
    if ok then return a, b, c, d, e end
    return nil
end

local function S(v)                                     -- any value to a short safe string
    if v == nil then return "nil" end
    if secret(v) then return "<secret>" end
    local ok, s = pcall(tostring, v)
    return ok and s or "<err>"
end

local function N(v)                                     -- a number to one decimal, "?" when unreadable
    if type(v) ~= "number" or secret(v) then return "?" end
    return string.format("%.1f", v)
end

local function Add(s)
    if #lines < MAX_LINES then lines[#lines + 1] = s
    elseif #lines == MAX_LINES then lines[#lines + 1] = "-- TRUNCATED: more lines were found than the probe keeps" end
end

local function Head(s) Add(""); Add("== " .. s) end

local function Name(o)
    if secret(o) then return "<secret>" end
    if o == nil then return "nil" end
    local n = type(o) == "table" and try(o.GetName, o) or nil
    if type(n) == "string" and not secret(n) and n ~= "" then return n end
    local d = type(o) == "table" and try(o.GetDebugName, o) or nil
    if type(d) == "string" and not secret(d) and d ~= "" then return d end
    local t = type(o) == "table" and try(o.GetObjectType, o) or nil
    return "<anon " .. S(t) .. ">"
end

local function Points(o)
    local n = try(o.GetNumPoints, o)
    if type(n) ~= "number" or secret(n) then return "?" end
    local out = {}
    for i = 1, n do
        local p, rel, rp, x, y = try(o.GetPoint, o, i)
        out[#out + 1] = S(p) .. ">" .. Name(rel) .. ":" .. S(rp) .. "(" .. N(x) .. "," .. N(y) .. ")"
    end
    return #out > 0 and table.concat(out, " ") or "none"
end

-- audit D39 (Dev Assist 0.7.19): a frame's own text can be a character name (a whisper tab is titled with the other player's name), and
-- the saved lines go into XayaUI.lua, the file players send. So text is only added for the lines shown in chat (ns.PrintPrivate), never
-- for the saved ones: withText is on only while those shown lines are built.
local withText = false
local function Texts(o)                                 -- visible text on the frame's own text regions (short; used to name buttons)
    if not withText then return "" end
    local out = {}
    local regs = { try(o.GetRegions, o) }
    for _, r in ipairs(regs) do
        local ot = try(r.GetObjectType, r)
        if not secret(ot) and ot == "FontString" then
            local t = try(r.GetText, r)
            if secret(t) then out[#out + 1] = "<secret>"
            elseif t ~= nil then out[#out + 1] = "'" .. S(t):sub(1, 24) .. "'" end
        end
        if #out >= 3 then break end
    end
    return #out > 0 and (" text=" .. table.concat(out, ",")) or ""
end

local function Describe(o)
    if type(o) ~= "table" or not o.GetObjectType then return S(o) end
    local ot = S(try(o.GetObjectType, o))
    local shown = try(o.IsShown, o)
    local vis = try(o.IsVisible, o)
    local par = try(o.GetParent, o)
    local w, h = try(o.GetSize, o)
    local s = Name(o) .. " [" .. ot .. "] shown=" .. S(shown) .. " vis=" .. S(vis)
    if o.GetAlpha then s = s .. " a=" .. N(try(o.GetAlpha, o)) end
    if o.GetFrameStrata then s = s .. " strata=" .. S(try(o.GetFrameStrata, o)) .. " lvl=" .. S(try(o.GetFrameLevel, o)) end
    s = s .. " size=" .. N(w) .. "x" .. N(h)
    s = s .. " L=" .. N(try(o.GetLeft, o)) .. " T=" .. N(try(o.GetTop, o))
    s = s .. " parent=" .. (par and Name(par) or "nil")
    s = s .. " pts=" .. Points(o)
    if ot == "Button" or ot == "CheckButton" then s = s .. Texts(o) end
    return s
end

-- Walk a frame's children down to a depth, one line per child.
local function Tree(o, depth, maxDepth, seen)
    if depth > maxDepth then return end
    local kids = { try(o.GetChildren, o) }
    local pad = string.rep("  ", depth)
    for _, c in ipairs(kids) do
        if not seen[c] then
            seen[c] = true
            Add(pad .. "- " .. Describe(c) .. Texts(c))
            Tree(c, depth + 1, maxDepth, seen)
        end
    end
    local regs = { try(o.GetRegions, o) }
    if #regs > 0 then
        local kinds = {}
        for _, r in ipairs(regs) do
            local ot = S(try(r.GetObjectType, r))
            local rn = try(r.GetName, r)
            kinds[#kinds + 1] = ot .. (type(rn) == "string" and (":" .. rn) or "")
        end
        Add(pad .. "  regions(" .. #regs .. "): " .. table.concat(kinds, ", "))
    end
end

local function Global(name) local v = _G[name]; return type(v) == "table" and v or nil end

local SUSPECTS = {
    "GeneralDockManager", "GeneralDockManagerOverflowButton", "GeneralDockManagerScrollFrame",
    "ChatFrameMenuButton", "ChatFrameChannelButton", "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton",
    "QuickJoinToastButton", "FriendsMicroButton", "ChatAlertFrame", "ChatConfigFrame", "ChatMenu", "VoiceChatChannelActivatedNotification",
    "FloatingChatFrameManager", "EditModeManagerFrame", "SocialToastButton", "QuickJoinFrame",
}

local function Run()
    lines = {}
    local frames = {}                                   -- chat objects, for the "what is anchored to chat" scan
    local nChat = ns.Compat.MaxChatWindows()
    local sw, sh = try(GetScreenWidth), try(GetScreenHeight)

    Head("environment")
    local ver, build, bdate, toc = try(GetBuildInfo)
    Add("game " .. S(ver) .. " build " .. S(build) .. " " .. S(bdate) .. " interface " .. S(toc))
    Add("XayaUI " .. S(ns.version or (C_AddOns and C_AddOns.GetAddOnMetadata and try(C_AddOns.GetAddOnMetadata, "XayaUI", "Version")) or "?"))
    Add("screen " .. N(sw) .. "x" .. N(sh) .. "  UIParent scale " .. N(UIParent and try(UIParent.GetScale, UIParent)) .. "  effective " .. N(UIParent and try(UIParent.GetEffectiveScale, UIParent)))
    Add("useUiScale=" .. S(try(GetCVar, "useUiScale")) .. " uiScale=" .. S(try(GetCVar, "uiScale")))
    Add("secrets API: issecretvalue=" .. S(type(issecretvalue)) .. " canaccessvalue=" .. S(type(canaccessvalue)) .. " C_Secrets=" .. S(type(C_Secrets)))
    if type(C_Secrets) == "table" then
        local names = {}
        for k in pairs(C_Secrets) do names[#names + 1] = tostring(k) end
        table.sort(names)
        Add("C_Secrets functions: " .. table.concat(names, ", "))
    end
    Add("DEFAULT_CHAT_FRAME=" .. Name(DEFAULT_CHAT_FRAME) .. " SELECTED_CHAT_FRAME=" .. Name(SELECTED_CHAT_FRAME) .. " max chat windows=" .. S(nChat))
    Add("FCF_GetNumActiveChatFrames=" .. S(try(FCF_GetNumActiveChatFrames)))
    Add("EditModeManagerFrame present: " .. S(Global("EditModeManagerFrame") ~= nil))

    Head("chat windows (GetChatWindowInfo: name, size, r,g,b,a, shown, locked, docked, uninteractable)")
    for i = 1, nChat do
        local name, size, r, g, b, a, shown, locked, docked, unint = try(GetChatWindowInfo, i)
        Add(i .. ": " .. S(name) .. " size=" .. S(size) .. " shown=" .. S(shown) .. " locked=" .. S(locked) .. " docked=" .. S(docked) .. " uninteractable=" .. S(unint))
    end

    Head("per window: the frame, its tab, edit box, button strip")
    for i = 1, nChat do
        local cf = Global("ChatFrame" .. i)
        if cf then
            frames[cf] = true
            Add("-- ChatFrame" .. i)
            Add(Describe(cf))
            Add("movable=" .. S(try(cf.IsMovable, cf)) .. " resizable=" .. S(try(cf.IsResizable, cf)) .. " clamped=" .. S(try(cf.IsClampedToScreen, cf)) .. " userPlaced=" .. S(try(cf.GetUserPlaced, cf)))
            local minW, minH, maxW, maxH = try(cf.GetResizeBounds, cf)
            Add("resize bounds min " .. N(minW) .. "x" .. N(minH) .. " max " .. N(maxW) .. "x" .. N(maxH))
            for _, suffix in ipairs({ "Tab", "EditBox", "ButtonFrame", "ResizeButton", "Background", "ScrollBar", "ClickAnywhereButton" }) do
                local o = Global("ChatFrame" .. i .. suffix) or (cf[suffix] and type(cf[suffix]) == "table" and cf[suffix]) or nil
                if o then frames[o] = true; Add("  " .. suffix .. ": " .. Describe(o)) else Add("  " .. suffix .. ": not found") end
            end
        end
    end

    local cf1 = Global("ChatFrame1")
    if cf1 then
        Head("ChatFrame1 full child tree (depth 3)")
        Tree(cf1, 0, 3, {})
        local eb = Global("ChatFrame1EditBox")
        if eb then
            Head("ChatFrame1EditBox")
            Add("altArrowKeyMode=" .. S(try(eb.GetAltArrowKeyMode, eb)) .. " chatType=" .. S(try(eb.GetAttribute, eb, "chatType")) .. " history=" .. S(try(eb.GetHistoryLines, eb)))
            Tree(eb, 0, 2, {})
        end
        local bf = Global("ChatFrame1ButtonFrame")
        if bf then Head("ChatFrame1ButtonFrame (Blizzard's side strip)"); Tree(bf, 0, 3, {}) end
        local tab = Global("ChatFrame1Tab")
        if tab then Head("ChatFrame1Tab"); Tree(tab, 0, 2, {}) end
    end
    local dock = Global("GeneralDockManager")
    if dock then frames[dock] = true; Head("GeneralDockManager (depth 2)"); Add(Describe(dock)); Tree(dock, 0, 2, {}) end

    Head("suspect frames by name (the floating button is probably one of these)")
    for _, n in ipairs(SUSPECTS) do
        local o = Global(n)
        if o then Add(n .. ": " .. Describe(o)) else Add(n .. ": not found") end
    end

    Head("secret-value behavior (message text is NOT recorded)")
    if cf1 then
        local num = try(cf1.GetNumMessages, cf1)
        Add("ChatFrame1:GetNumMessages() = " .. S(num))
        if type(num) == "number" and not secret(num) and num > 0 and cf1.GetMessageInfo then
            local idx = num
            local text = try(cf1.GetMessageInfo, cf1, idx)
            Add("last message: type=" .. type(text) .. " secret=" .. S(secret(text)) .. " canaccess=" .. S(canaccessvalue and try(canaccessvalue, text) or "n/a"))
            if type(text) == "string" and not secret(text) then Add("last message length=" .. S(try(string.len, text))) end
        else
            Add("GetMessageInfo not testable now (no messages or no such method)")
        end
        Add("ChatFrame1.AddMessage=" .. S(type(cf1.AddMessage)) .. " GetFontObject=" .. S(type(cf1.GetFontObject)) .. " SetFading=" .. S(type(cf1.SetFading)))
        Add("ChatFrame1 fading=" .. S(try(cf1.GetFading, cf1)) .. " fadeDuration=" .. S(try(cf1.GetFadeDuration, cf1)) .. " timeVisible=" .. S(try(cf1.GetTimeVisible, cf1)))
    end

    local topLeft = {}                                  -- shown frames whose first anchor puts them in the top-left 420x420 of the screen
    local topLeftShown = {}                             -- the same, with their own text, for the chat output only (never saved)
    local anchored = {}                                 -- frames with an anchor on a chat object
    local total = 0
    if type(EnumerateFrames) == "function" and type(sw) == "number" and type(sh) == "number" then
        local f = EnumerateFrames()
        while f do
            total = total + 1
            local shown = try(f.IsShown, f)
            local nPts = try(f.GetNumPoints, f)
            if type(nPts) == "number" and not secret(nPts) then
                for i = 1, nPts do
                    local _, rel = try(f.GetPoint, f, i)
                    if not secret(rel) and rel and frames[rel] and f ~= rel then anchored[#anchored + 1] = Name(f) .. " shown=" .. S(shown) .. " -> " .. Name(rel) end
                end
            end
            -- shown can come back secret (Midnight): comparing a secret raises, so it is checked first (the 0.6.4 error at Probe.lua:229)
            if not secret(shown) and shown == true then
                local l, t = try(f.GetLeft, f), try(f.GetTop, f)
                if type(l) == "number" and type(t) == "number" and not secret(l) and not secret(t) and l < 420 and t > sh - 420 then
                    topLeft[#topLeft + 1] = Describe(f)
                    withText = true; topLeftShown[#topLeftShown + 1] = Describe(f) .. Texts(f); withText = false
                end
            end
            f = EnumerateFrames(f)
        end
    else
        Add("EnumerateFrames or screen size not available")
    end

    Head("frames anchored to a chat object (" .. #anchored .. " of " .. total .. " frames scanned)")
    for i, s in ipairs(anchored) do if i <= 120 then Add(s) end end

    Head("shown frames in the top-left 420x420 of the screen (" .. #topLeft .. ")")
    for i, s in ipairs(topLeft) do if i <= 80 then Add(s) end end

    CueRulesDB = CueRulesDB or {}
    CueRulesDB.chatProbe = { when = date("%Y-%m-%d %H:%M:%S"), lines = lines }
    return #lines, topLeftShown
end

-- /xui debug chatprobe
function ns.ChatProbe()
    local ok, count, topLeft = pcall(Run)
    if not ok then
        ns.Print("chat probe failed: " .. S(count) .. "  (it only reads; nothing was changed)")
        return
    end
    ns.Print("chat probe: " .. count .. " lines kept. Type /reload (or log out) so they are saved, then tell Claude it is done.")
    local shown = 0
    for _, s in ipairs(topLeft) do
        local nm = s:match("^(%S+)")
        if nm and not nm:find("^<anon") then
            shown = shown + 1
            -- a frame's own text can be a character name (player, target, party frames): shown, never recorded (Core.lua ns.PrintPrivate)
            local say = ns.PrintPrivate or ns.Print
            if shown <= 6 then say("  top-left: " .. s:sub(1, 150)) end
        end
    end
    if shown == 0 then ns.Print("  no named frames in the top-left corner (unnamed ones are in the saved report)") end
end

-------------------------------------------------------------------------------
-- Plugs into core through Modules.lua (0.5.108): core never calls this file by name.
-------------------------------------------------------------------------------
-- /xui debug chatprobe (core 0.6.50 runs diagnostics only there). The fallback (/xui chatprobe) is for a core older than 0.6.50.
ns.RegisterDebugCommand("chatprobe", function() ns.ChatProbe() end, "chatprobe (read-only chat frame report)")
