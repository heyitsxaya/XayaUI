-------------------------------------------------------------------------------
-- QAWalks-debug-chatdefaults.lua (XayaUI_DevAssist 0.7.69): in-game QA walkthrough for "Debug chat defaults" (XayaUI Chat 0.6.46; QA D29).
-- Found by the P5 worker: in the game the Sidebar's and the privacy cover's defaults never reached the saved settings at login (the
-- Sidebar's "Fade with the chat" on by default, REQUEST-LOG O-143, Xaya 2026-11-07: "the sidebar icons should also be fading"; issue #494
-- may be related). Chat 0.6.46 fills every missing key with its default at login; a value you saved is never changed.
-- Two parts around a /reload:
--   part 1: the live sidebar settings (sbOn, sbFade, sbSide, sbShow, sbBg, sbPriv) and the privacy cover's (colour, fill mode, texture,
--           button opacity and size, cover opacity) read back, each marked (s) saved in your file or (d) missing from it and given its
--           default at this login (XayaUI Chat's C.filledAtLogin); then the chat fade turned on for a moment: the sidebar follows its
--           "Fade with the chat" tick; your fade settings are put back by the last step;
--   part 2: after the /reload, the same settings read again: every one now (s) saved, with the value part 1 read.
-- Standing rule V22 (Xaya 2026-11-07): each check offers its verdict (prefill = true; recorded only on her click) and keeps what it read in
-- the note. Reaches XayaUI Chat only through core (ns.Settings("chat"), the "chatDebug" service). UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local function Ch() local ns = NS(); local sv = ns and ns.Service and ns.Service("chatDebug"); return sv and sv.C end
local function View() local ns = NS(); return ns and ns.Settings and ns.Settings("chat") end
local function Alpha(f) if not (f and f.GetAlpha) then return nil end local ok, v = pcall(f.GetAlpha, f); local C = Ch(); if ok and type(v) == "number" and not (C and C.IsSecret and C.IsSecret(v)) then return v end end
local function Shown(f) if not (f and f.IsShown) then return false end local ok, v = pcall(f.IsShown, f); return ok and v and true or false end

local SB = { "sbOn", "sbFade", "sbSide", "sbShow", "sbBg", "sbPriv" }
local PRIV = { "privRGB", "privMode", "privTexture", "privBtnAlpha", "privBtnSize", "privAlpha" }

local function Val(v)
    if type(v) == "number" then return ("%g"):format(v) end
    if type(v) == "string" then return (v:match("([^\\]+)$") or v) end   -- a texture path: its file name
    return tostring(v)
end
-- the value text and whether it took its default at this login (d) or came from the saved file (s)
local function Read(part, key)
    local V, C = View(), Ch()
    local t = V and V[part]
    local filled = C and C.filledAtLogin and C.filledAtLogin[part] or {}
    if type(t) ~= "table" then return nil end
    if key == "privRGB" then
        if t.privR == nil or t.privG == nil or t.privB == nil then return nil end
        return Val(t.privR) .. "/" .. Val(t.privG) .. "/" .. Val(t.privB), (filled.privR or filled.privG or filled.privB) and "d" or "s"
    end
    if t[key] == nil then return nil end
    return Val(t[key]), filled[key] and "d" or "s"
end
-- every default of that part has a value now; the note lists the keys asked for, "key=value(s|d)"
local function Capture(part, keys, defaults)
    local C = Ch()
    if not C then return false, "XayaUI Chat is not loaded" end
    if not C.filledAtLogin then return false, "XayaUI Chat is older than 0.6.46, or both of its switches are off (Chat Panel, Improved Chat): no defaults were filled at this login" end
    local V = View(); local t = V and V[part]
    if type(t) ~= "table" then return false, "the chat settings are not loaded" end
    local missing, out = {}, {}
    for k in pairs(defaults or {}) do if t[k] == nil then missing[#missing + 1] = k end end
    table.sort(missing)
    for _, k in ipairs(keys) do
        local v, how = Read(part, k)
        out[#out + 1] = k .. "=" .. (v and (v .. "(" .. how .. ")") or "MISSING")
    end
    return #missing == 0, (#missing == 0 and "" or ("missing: " .. table.concat(missing, ",") .. " | ")) .. table.concat(out, " ")
end
-- part 2: each key read again: saved now (s), with the value part 1 read
local function Again(part, keys, step)
    local note = QA.SeenNote and QA.SeenNote("debug-chatdefaults", step)
    if not note or not note:find("=", 1, true) then return nil, "part 1 has no record: run it to its end first (press Done before the /reload)" end
    local C = Ch()
    if not (C and C.filledAtLogin) then return false, "XayaUI Chat is older than 0.6.46, or both of its switches are off" end
    local bad, out = {}, {}
    for _, k in ipairs(keys) do
        local before = note:match(k .. "=([^%s%(]+)")
        local v, how = Read(part, k)
        out[#out + 1] = k .. "=" .. tostring(v) .. "(" .. tostring(how) .. ")"
        if not v then bad[#bad + 1] = k .. " missing"
        elseif how ~= "s" then bad[#bad + 1] = k .. " not saved"
        elseif before and before ~= v then bad[#bad + 1] = k .. " was " .. before end
    end
    return #bad == 0, (#bad == 0 and "all saved, as part 1 read: " or (table.concat(bad, ", ") .. " | ")) .. table.concat(out, " ")
end

local fdSaved
QA.Register("debug-chatdefaults", { title = "Chat defaults reach your saved settings (part 1 of 2) (D29, O-143)", area = "Chat", qa = "D29", order = 241.1, prefill = true, steps = {
    { text = "Nothing to do: the check reads the chat sidebar's settings as XayaUI Chat uses them now: Show the chat sidebar (sbOn), Fade with the chat (sbFade), Side (sbSide), Show (sbShow), Background (sbBg), Privacy cover button in the sidebar (sbPriv). Each is marked (s) when it came from your saved settings, (d) when it was missing there and took its default at this login.\n\n|cffffd100Expect:|r no setting MISSING. On the first login after this update most read (d) with their defaults (sbOn=true, sbFade=true, sbSide=LEFT, sbShow=ALWAYS, sbBg=true, sbPriv=true); one you changed yourself reads (s) with your value.",
        check = function() local C = Ch(); return Capture("chat2", SB, C and C.SIDEBAR_DEFAULTS) end },
    { text = "Nothing to do: the same for the privacy cover: its color (privRGB), fill (privMode), texture (privTexture), button opacity (privBtnAlpha), button size (privBtnSize) and cover opacity (privAlpha).\n\n|cffffd100Expect:|r no setting MISSING. Defaults: privRGB=0.04/0.04/0.06, privMode=COLOR, privTexture=UI-DialogBox-Background, privBtnAlpha=90, privBtnSize=28, privAlpha=100 (your own values where you changed them).",
        check = function() local ns = NS(); return Capture("chat", PRIV, ns and ns.CHAT_DEFAULTS) end },
    { text = "Press |cffffd100Do it for me|r: Fade the chat when it is idle is turned on, after 3 seconds (your fade settings are remembered and put back by the last step). Move the mouse away from the chat, wait 5 seconds, then press |cffffd100Check again|r.\n\n|cffffd100Expect:|r with Fade with the chat ticked (QoL > Improved Chat > Sidebar; on by default) the sidebar fades away with the chat; unticked, it stays at full strength.",
        setup = function()
            local V, C = View(), Ch(); local s = V and V.chat2
            if not (s and C) then return end
            fdSaved = fdSaved or { fadeOn = s.fadeOn, fadeAfter = s.fadeAfter, fadeTo = s.fadeTo, fadeHover = s.fadeHover }
            s.fadeOn, s.fadeAfter, s.fadeTo, s.fadeHover = true, 3, 0, true
            C.Refresh()
        end,
        check = function()
            local V, C = View(), Ch(); local s = V and V.chat2
            if not (s and C) then return false, "XayaUI Chat is not loaded" end
            local sb = C.Sidebar and C.Sidebar()
            if not (C.SidebarOn and C.SidebarOn() and sb and Shown(sb)) then return nil, "the sidebar is not showing (QoL > Improved Chat > Sidebar > Show the chat sidebar, or Improved Chat is off): nothing to check" end
            if not s.fadeOn then return nil, "press Do it for me first" end
            if (C.fade or 1) > 0.05 then return false, ("the chat has not faded yet (opacity %.2f): move the mouse away and wait"):format(C.fade or 1) end
            local a = Alpha(sb) or 1
            -- the tick as its settings page shows it (Sidebar.lua: a missing value shows its default, ticked), so the check also catches
            -- the page and the sidebar disagreeing (Chat 0.6.45 in the game: ticked on the page, no fade)
            local ticked = s.sbFade ~= false
            local ok = (ticked and a <= 0.05) or (not ticked and a >= 0.95)
            local how = s.sbFade == nil and "missing" or ((C.filledAtLogin and C.filledAtLogin.chat2 and C.filledAtLogin.chat2.sbFade) and "default" or "saved")
            return ok and true or false, ("Fade with the chat %s (%s); chat opacity %.2f, sidebar opacity %.2f: it %s"):format(ticked and "ticked" or "unticked",
                how, C.fade or 1, a, ok and (ticked and "fades" or "stays") or ("should " .. (ticked and "fade" or "stay")))
        end },
    { done = true, text = "Press |cffffd100Do it for me|r to put your fade settings back as they were, then |cffffd100Done|r (so this record is kept). Type |cffffd100/reload|r and run \"Chat defaults reach your saved settings: after the /reload (part 2 of 2) (D29)\".",
        setup = function()
            local V, C = View(), Ch(); local s = V and V.chat2
            if s and C and fdSaved then for k, v in pairs(fdSaved) do s[k] = v end; fdSaved = nil; C.Refresh() end
        end,
        check = function() return fdSaved == nil, fdSaved == nil and "fade settings put back" or "not put back yet: press Do it for me" end },
} })

QA.Register("debug-chatdefaults-reload", { title = "Chat defaults reach your saved settings: after the /reload (part 2 of 2) (D29)", area = "Chat", qa = "D29", order = 241.2, prefill = true, steps = {
    { text = "Run this after part 1 and its /reload. Nothing to do: the sidebar's settings are read again.\n\n|cffffd100Expect:|r every one now reads (s), saved in your settings file, with the value part 1 read.",
        check = function() return Again("chat2", SB, 1) end },
    { text = "Nothing to do: the privacy cover's settings are read again.\n\n|cffffd100Expect:|r every one reads (s) with the value part 1 read.",
        check = function() return Again("chat", PRIV, 2) end },
} })
