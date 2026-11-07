-------------------------------------------------------------------------------
-- NotepadShare.lua : share a note to chat, and export / import notes as text. Own code. UNTESTED in game.
--
-- Share: the toolbar's menu (three lines) button > "Share this note..." asks for a channel (party, raid, instance, guild, or a whisper), then
--   * sends the note as hidden addon messages (prefix XUINOTE, split into chunks, paced to stay under the addon message limit), and
--   * optionally posts the first lines of its text as ordinary chat lines, so players without XayaUI can read it too.
--   Another XayaUI user gets a small window offering the note: Save (as a new note at the end of their list) or Dismiss.
--   Nothing is ever saved without a click. Shared text is cleaned first (links, textures and escape codes removed, colors kept).
-- Export / import: plain text. One note, or all notes, in a block you copy (Ctrl+A, Ctrl+C) and paste anywhere; the same window
--   imports such a block (or any plain text, as one note) and adds the notes at the end of the list.
--
-- Limits that come from the game (warcraft.wiki.gg, API_C_ChatInfo.SendAddonMessage): 255 characters per message, 10 messages
-- burst then 1 per second per prefix; Midnight pauses addon messages during boss encounters and Mythic+ runs (this addon refuses to
-- send while IsEncounterInProgress() is true). A full 8000-character note is about 40 chunks, so roughly 30 seconds to send.
-------------------------------------------------------------------------------
local ADDON, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (this addon depends on it: ## Dependencies: XayaUI)
-- spacing from core (#351 phase 2, XayaUI/Modules.lua): M inside every window's edge, G between two controls
local M, G = ns.UI_MARGIN, ns.UI_GUTTER

local PREFIX = "XUINOTE"
local CHUNK = 200            -- encoded characters per addon message (limit is 255 including the small header)
local MAX_CHUNKS = 60
local MAX_PENDING = 5        -- offers waiting at once; more are ignored until some are answered
local MAX_IMPORT = 100       -- notes per import
local ASSEMBLE_SECS = 120
local BURST, REFILL = 8, 1.05   -- send pacing: 8 at once, then one per ~1 second

local function MaxChars() return ns.Notepad_MAX_CHARS or 8000 end
local function Say(msg) if ns.Print then ns.Print(msg) else print("XayaUI: " .. msg) end end
-- a message naming another player: shown, never kept in the debug record or a bug report (XayaUI/Core.lua ns.PrintPrivate)
local function SayPrivate(msg) local p = ns.PrintPrivate or ns.Print; if p then p(msg) else print("XayaUI: " .. msg) end end
local function DB() return ns.notepadDB end

-------------------------------------------------------------------------------
-- text helpers (pure; unit-tested outside the game)
-------------------------------------------------------------------------------
-- Clean text that came from somewhere else: no control characters, no hyperlinks (keeps their visible text), no textures,
-- no secret-string escapes; color codes (|cAARRGGBB ... |r) and the pipe character itself are kept. Anything else starting with | is dropped.
function ns.NotepadShare_Clean(text, maxChars)
    text = tostring(text or "")
    text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
    text = text:gsub("[%z\1-\8\11-\31\127]", "")
    text = text:gsub("|H[^|]*|h(.-)|h", "%1")
    text = text:gsub("|K.-|k", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
    text = text:gsub("||", "\1")
    text = text:gsub("|c(%x%x%x%x%x%x%x%x)", "\2%1")
    text = text:gsub("|r", "\3")
    text = text:gsub("|", "")
    text = text:gsub("\1", "||"):gsub("\2", "|c"):gsub("\3", "|r")
    if maxChars and #text > maxChars then
        text = text:sub(1, maxChars)
        text = text:gsub("[\192-\255][\128-\191]*$", "")   -- do not leave half a UTF-8 character at the cut
    end
    return text
end

-- transport encoding: keeps the three characters that matter to the chunk format out of the payload
local function Enc(text) return (text:gsub("[%%|\n]", function(c) return ("%%%02X"):format(c:byte()) end)) end
local function Dec(text) return (text:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)) end
ns.NotepadShare_Enc, ns.NotepadShare_Dec = Enc, Dec

-- split an encoded string into pieces of at most n characters, never inside a %XX escape or a UTF-8 character
function ns.NotepadShare_Chunks(enc, n)
    n = n or CHUNK
    local out, i, len = {}, 1, #enc
    while i <= len do
        local j = math.min(i + n - 1, len)
        if j < len then
            -- step back out of an escape (%, %X) or a multi-byte character
            local k = j
            while k > i and (enc:sub(k, k) == "%" or enc:sub(k - 1, k - 1) == "%" and k - 1 >= i or enc:byte(k + 1) and enc:byte(k + 1) >= 128 and enc:byte(k + 1) < 192) do k = k - 1 end
            if k > i then j = k end
        end
        out[#out + 1] = enc:sub(i, j)
        i = j + 1
    end
    if #out == 0 then out[1] = "" end
    return out
end

local function Title(text)
    local first = (text or ""):match("^%s*([^\n]+)") or ""
    first = first:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", ""):gsub("^[#%-%*%s%[%]xX]+", "")
    first = first:gsub("{spell:([^}]*)}", function(a) local nm = ns.Notepad_SpellInfo and select(2, ns.Notepad_SpellInfo(a)); return nm and ("spell " .. nm) or ("spell " .. a:gsub("^%s+", ""):gsub("%s+$", "")) end)
    if #first > 50 then first = first:sub(1, 47):gsub("[\192-\255][\128-\191]*$", "") .. "..." end
    return first ~= "" and first or "(untitled)"
end
ns.NotepadShare_Title = Title

-- text safe to post as an ordinary chat line: no escape codes; {spell:ID} becomes a clickable spell link when the game can make one
local function ChatSafe(line)
    line = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|H[^|]*|h(.-)|h", "%1"):gsub("|", "/")
    line = line:gsub("{spell:([^}]*)}", function(a)
        local id, name = nil, nil
        if ns.Notepad_SpellInfo then id, name = ns.Notepad_SpellInfo(a) end
        id = id or tonumber((tostring(a):gsub("%s", "")))
        if id and C_Spell and C_Spell.GetSpellLink then
            local ok, link = pcall(C_Spell.GetSpellLink, id)
            if ok and type(link) == "string" and link ~= "" then return link end
        end
        return "[spell " .. tostring(name or id or (tostring(a):gsub("^%s+", ""):gsub("%s+$", ""))) .. "]"
    end)
    return line
end
ns.NotepadShare_ChatSafe = ChatSafe

-- visible lines for a note: a header, then up to maxLines lines of its text (each cut to 240 characters)
function ns.NotepadShare_ChatLines(text, withText, maxLines)
    maxLines = maxLines or 6
    local lines = { ("[XayaUI note] %s (%d characters). XayaUI users are offered it to save."):format(ChatSafe(Title(text)), #text) }
    if withText then
        local n, more = 0, false
        for raw in (text .. "\n"):gmatch("(.-)\n") do
            local line = ChatSafe(raw):gsub("^%s+", "")
            if line ~= "" then
                if n >= maxLines then more = true; break end
                n = n + 1
                if #line > 240 then line = line:sub(1, 237):gsub("[\192-\255][\128-\191]*$", "") .. "..." end
                lines[#lines + 1] = line
            end
        end
        if more then lines[#lines + 1] = "(more in the note; the full text goes to XayaUI users)" end
    end
    return lines
end

-- export format --------------------------------------------------------------------------------------------------------------
local HEADER, MARK = "XAYAUI-NOTES 1", "=== note ==="
local function EscLine(l) if l:sub(1, 3) == "===" or l:sub(1, 1) == "\\" then return "\\" .. l end return l end
local function UnescLine(l) if l:sub(1, 1) == "\\" and (l:sub(2, 4) == "===" or l:sub(2, 2) == "\\") then return l:sub(2) end return l end

function ns.NotepadShare_Export(texts)
    local out = { HEADER }
    for _, t in ipairs(texts) do
        out[#out + 1] = MARK
        for line in (tostring(t or "") .. "\n"):gmatch("(.-)\n") do out[#out + 1] = EscLine(line) end
    end
    return table.concat(out, "\n")
end

-- returns a list of note texts: the notes of an export block, or the whole text as one note when it is not an export block
function ns.NotepadShare_Parse(str)
    str = tostring(str or ""):gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("%s+$", "")   -- trailing blank lines from copying are not part of the last note
    local lines = {}
    for line in (str .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
    local first = 1
    while lines[first] and not lines[first]:match("%S") do first = first + 1 end
    local out = {}
    if lines[first] and lines[first]:match("^%s*XAYAUI%-NOTES%s+%d+%s*$") then
        local cur
        for i = first + 1, #lines do
            local l = lines[i]
            if l == MARK then
                if cur then out[#out + 1] = table.concat(cur, "\n") end
                cur = {}
            elseif cur then
                cur[#cur + 1] = UnescLine(l)
            end
        end
        if cur then out[#out + 1] = table.concat(cur, "\n") end
    elseif str:match("%S") then
        out[1] = str
    end
    return out
end

-------------------------------------------------------------------------------
-- sending
-------------------------------------------------------------------------------
-- V14 (Bonus 0.6.12; Xaya 2026-11-05: "anything that is disabled in the addon through a tick box should NEVER LOAD or contribute to
-- performance cost / demand in any way"). The send pump runs only while a note is being sent: its OnUpdate is set by
-- ns.NotepadShare_Send and cleared when the queue is empty (up to 0.6.11 it ran on every frame from login, with nothing to send). The
-- tokens it would have refilled while stopped are added when it starts again (pumpStopped), so the pacing is the same.
local sendQueue, tokens, sending = {}, BURST, nil
local pump, pumpStopped
local function Now() return GetTime and GetTime() or 0 end
local function StopPump()
    if pump then pump:SetScript("OnUpdate", nil) end
    pumpStopped = Now()
end

local function ResultOK(...)
    local r = select(select("#", ...), ...)   -- the result is the last return value (older clients return a boolean)
    if r == nil or r == true or r == 0 then return true end
    local E = Enum and Enum.SendAddonMessageResult
    if E and r == E.Success then return true end
    return false, r
end

local function SendOne(item)
    local ok, a, b
    ok, a, b = pcall(function() return C_ChatInfo.SendAddonMessage(PREFIX, item.msg, item.channel, item.target) end)
    if not ok then return false, a end
    return ResultOK(a, b)
end

local function Pump(_, dt)
    tokens = math.min(BURST, tokens + dt / REFILL)   -- the game allows a burst, then about one message a second
    if #sendQueue == 0 then StopPump(); return end
    while tokens >= 1 and #sendQueue > 0 do
        if ns.Compat.InEncounter() then return end   -- wait: addon messages are paused in encounters
        local item = table.remove(sendQueue, 1)
        local ok, err = SendOne(item)
        if not ok then
            for i = #sendQueue, 1, -1 do if sendQueue[i].sid == item.sid then table.remove(sendQueue, i) end end
            Say("Sharing stopped: the game refused a message (" .. tostring(err) .. "). Try again in a moment.")
            sending = nil
            return
        end
        tokens = tokens - 1
        if item.last then Say("Note shared (" .. item.total .. " parts sent).") ; sending = nil end
    end
    if #sendQueue == 0 then StopPump() end
end
local function StartPump()
    if pumpStopped then tokens = math.min(BURST, tokens + (Now() - pumpStopped) / REFILL); pumpStopped = nil end
    pump = pump or CreateFrame("Frame")
    if not pump:GetScript("OnUpdate") then pump:SetScript("OnUpdate", Pump) end
end

local function NewSid()
    local chars, t = "abcdefghjkmnpqrstuvwxyz23456789", {}
    for i = 1, 4 do local k = math.random(1, #chars); t[i] = chars:sub(k, k) end
    return table.concat(t)
end

-- channel = PARTY | RAID | INSTANCE_CHAT | GUILD | WHISPER (target = name); withText = also post lines of text to that chat channel
function ns.NotepadShare_Send(text, channel, target, withText)
    text = ns.NotepadShare_Clean(text, MaxChars())
    if not text:match("%S") then return false, "The note is empty." end
    if ns.Compat.InEncounter() then return false, "Sharing is paused during a boss encounter. Try again afterwards." end
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
        local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
        if ok and locked then return false, "Chat messaging is locked right now (a restricted activity). Try again afterwards." end
    end
    if sending then return false, "A note is still being sent. Wait for it to finish." end
    if channel == "WHISPER" and (not target or target == "") then return false, "Enter the name of the player to whisper." end
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false, "Addon messages are not available." end
    if C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end

    local pieces = ns.NotepadShare_Chunks(Enc(text), CHUNK)
    if #pieces > MAX_CHUNKS then return false, "The note is too long to share." end
    local sid = NewSid()
    for i, piece in ipairs(pieces) do
        sendQueue[#sendQueue + 1] = { sid = sid, msg = ("D|%s|%d|%d|%s"):format(sid, i, #pieces, piece), channel = channel, target = target,
            last = (i == #pieces), total = #pieces }
    end
    sending = sid
    StartPump()

    if withText or true then   -- the header line always goes out (it tells everyone what is happening); the text lines are the option
        for _, line in ipairs(ns.NotepadShare_ChatLines(text, withText)) do
            local ok, sent = false, nil
            if ns.Compat and ns.Compat.SendChatMessage then ok, sent = pcall(ns.Compat.SendChatMessage, line, channel, nil, target) end   -- core module (Compat.lua)
            if not (ok and sent) then Say("The chat line could not be posted (chat may be locked); the note itself is still being sent."); break end
        end
    end
    return true, #pieces
end

-------------------------------------------------------------------------------
-- receiving
-------------------------------------------------------------------------------
local assembling = {}   -- sender .. sid -> { n, got, parts, t, sender }
local pending = {}      -- completed offers waiting for an answer: { sender, text }
local blocked = {}      -- senders blocked this session
local offerFrame

local function ShortName(sender) return (tostring(sender or "?"):gsub("%-.*$", "")) end
local function Me() return UnitName and UnitName("player") end

local ShowOffer, WaitCombat
local function Offer(sender, text)
    local db = DB()
    if not (db and db.acceptShares) then return end
    if blocked[sender] or #pending >= MAX_PENDING then return end
    text = ns.NotepadShare_Clean(text, MaxChars())
    if not text:match("%S") then return end
    pending[#pending + 1] = { sender = sender, text = text }
    if InCombatLockdown and InCombatLockdown() then WaitCombat(true); return end   -- shown when combat ends
    ShowOffer()
end

local accepting = false   -- "Accept notes shared by other XayaUI users", cached by ns.NotepadShare_Sync
local function Handle(prefix, msg, channel, sender)
    if not accepting or prefix ~= PREFIX or type(msg) ~= "string" then return end
    if issecretvalue and (issecretvalue(msg) or issecretvalue(sender)) then return end
    sender = tostring(sender or "")
    if sender == "" or ShortName(sender) == Me() then return end
    if channel ~= "PARTY" and channel ~= "RAID" and channel ~= "INSTANCE_CHAT" and channel ~= "GUILD" and channel ~= "WHISPER" then return end
    local sid, i, n, payload = msg:match("^D|(%w%w%w%w)|(%d+)|(%d+)|(.*)$")
    i, n = tonumber(i), tonumber(n)
    if not (sid and i and n and n >= 1 and n <= MAX_CHUNKS and i >= 1 and i <= n) then return end
    local now = GetTime and GetTime() or 0
    for k, a in pairs(assembling) do if now - a.t > ASSEMBLE_SECS then assembling[k] = nil end end
    local key = sender .. sid
    local a = assembling[key]
    if not a then a = { n = n, got = 0, parts = {}, t = now, sender = sender }; assembling[key] = a end
    if a.n ~= n then assembling[key] = nil return end
    if not a.parts[i] then a.parts[i] = payload; a.got = a.got + 1 end
    a.t = now
    if a.got == a.n then
        assembling[key] = nil
        Offer(sender, Dec(table.concat(a.parts)))
    end
end
ns.NotepadShare_Handle = Handle   -- also used by the tests

-------------------------------------------------------------------------------
-- offer window (the receiver's side)
-------------------------------------------------------------------------------
local function BuildOffer()
    if offerFrame then return offerFrame end
    local f = CreateFrame("Frame", "XayaUINoteOffer", UIParent, "BackdropTemplate")
    f:SetSize(320, 220); f:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
    f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true)
    f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(0.06, 0.06, 0.06, 0.95); f:SetBackdropBorderColor(0.2, 0.7, 1, 1)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal"); f.title:SetPoint("TOPLEFT", M, -M); f.title:SetPoint("TOPRIGHT", -M, -M); f.title:SetJustifyH("LEFT")
    f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3); f.sub:SetTextColor(0.6, 0.6, 0.6)
    -- the text: under the title and its subtitle (about 40 px), G above the 22 px button row
    local sf = CreateFrame("ScrollFrame", nil, f); sf:SetPoint("TOPLEFT", M, -(M + 40)); sf:SetPoint("BOTTOMRIGHT", -M, M + 22 + G); sf:EnableMouseWheel(true)
    local c = CreateFrame("Frame", nil, sf); c:SetSize(290, 10); sf:SetScrollChild(c)
    f.body = c:CreateFontString(nil, "OVERLAY"); f.body:SetFontObject(ChatFontNormal or GameFontHighlight)
    f.body:SetPoint("TOPLEFT"); f.body:SetPoint("TOPRIGHT"); f.body:SetJustifyH("LEFT"); f.body:SetJustifyV("TOP")
    sf:SetScript("OnMouseWheel", function(self, d) self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - d * 30))) end)
    f.sf, f.c = sf, c
    local function Btn(label, w, x, fn)
        local b = CreateFrame("Button", nil, f)
        b:SetSize(w, 22); b:SetPoint("BOTTOMLEFT", x, M)
        b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(); b.bg:SetColorTexture(0.18, 0.18, 0.18, 0.95)
        b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(0.2, 0.7, 1, 0.35)
        b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.fs:SetPoint("CENTER"); b.fs:SetText(label)
        b:SetScript("OnClick", fn)
        return b
    end
    local function Next() table.remove(pending, 1); if #pending > 0 then ShowOffer() else f:Hide() end end
    f.save = Btn("Save as new note", 120, M, function()
        local o = pending[1]
        if o then
            local pos = ns.Notepad_AddNote and ns.Notepad_AddNote(o.text)
            SayPrivate(pos and ("Saved " .. ShortName(o.sender) .. "'s note as note " .. pos .. ". Open it with /xui notes, then the list button.") or "The note could not be saved.")
        end
        Next()
    end)
    f.dismiss = Btn("Dismiss", 70, M + 120 + G, Next)
    f.block = Btn("Block sender", 90, M + 120 + G + 70 + G, function()   -- ends M from the right edge (320 wide)
        local o = pending[1]
        if o then
            blocked[o.sender] = true
            for i = #pending, 1, -1 do if pending[i].sender == o.sender then table.remove(pending, i) end end
            SayPrivate("Ignoring shared notes from " .. ShortName(o.sender) .. " until you log out or reload.")
        end
        if #pending > 0 then ShowOffer() else f:Hide() end
    end)
    f:Hide()
    offerFrame = f
    return f
end

ShowOffer = function()
    local o = pending[1]; if not o then return end
    local f = BuildOffer()
    f.title:SetText(ShortName(o.sender) .. " shared a note")
    f.sub:SetText(("%d characters%s"):format(#o.text, #pending > 1 and (", " .. (#pending - 1) .. " more waiting") or ""))
    f.body:SetText(o.text:sub(1, 1500) .. (#o.text > 1500 and "\n..." or ""))
    f.c:SetHeight(math.max(10, f.body:GetStringHeight() + 4))
    f.sf:SetVerticalScroll(0)
    f:Show()
end

-------------------------------------------------------------------------------
-- share window (the sender's side)
-------------------------------------------------------------------------------
local shareFrame
local CHANNELS = {
    { "INSTANCE_CHAT", "Instance chat", function() return IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) end },
    { "RAID",          "Raid",          function() return IsInRaid and IsInRaid() end },
    { "PARTY",         "Party",         function() return IsInGroup and IsInGroup() end },
    { "GUILD",         "Guild",         function() return IsInGuild and IsInGuild() end },
    { "WHISPER",       "Whisper",       function() return true end },
}
local function Available()
    local out = {}
    for _, c in ipairs(CHANNELS) do local ok, v = pcall(c[3]); if ok and v then out[#out + 1] = c end end
    return out
end

local function BuildShare()
    if shareFrame then return shareFrame end
    local f = CreateFrame("Frame", "XayaUINoteShare", UIParent, "BackdropTemplate")
    f:SetSize(300, 210); f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)   -- (176 before #351 phase 2: the status ran into the buttons)
    f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true)
    f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(0.06, 0.06, 0.06, 0.95); f:SetBackdropBorderColor(0.2, 0.7, 1, 1)
    local function Text(parent, size, ...) local fs = parent:CreateFontString(nil, "OVERLAY", size or "GameFontHighlightSmall"); fs:SetPoint(...); return fs end
    -- rows, top to bottom (#351 phase 2): title M from the top; the note's name G under the close x (it spans the width); then the
    -- channel row, the player row, the "post text" button and the status, G apart; the buttons M from the bottom
    f.title = Text(f, "GameFontNormal", "TOPLEFT", M, -M); f.title:SetText("Share this note")
    f.what = Text(f, "GameFontHighlightSmall", "TOPLEFT", M, -30); f.what:SetPoint("TOPRIGHT", -M, -30); f.what:SetJustifyH("LEFT"); f.what:SetWordWrap(false)
    local function Btn(label, w, h, fn)
        local b = CreateFrame("Button", nil, f)
        b:SetSize(w, h)
        b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(); b.bg:SetColorTexture(0.18, 0.18, 0.18, 0.95)
        b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(0.2, 0.7, 1, 0.35)
        b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.fs:SetPoint("CENTER"); b.fs:SetText(label)
        b:SetScript("OnClick", fn)
        return b
    end
    f.chLabel = Text(f, "GameFontHighlightSmall", "TOPLEFT", M, -56); f.chLabel:SetText("Send to")
    f.ch = Btn("", 150, 20, function()
        local av = Available(); if #av == 0 then return end
        local cur = 1
        for i, c in ipairs(av) do if c[1] == f.channel then cur = i end end
        f.channel = av[(cur % #av) + 1][1]
        f:Sync()
    end)
    f.ch:SetPoint("TOPLEFT", 70, -52)
    f.nameLabel = Text(f, "GameFontHighlightSmall", "TOPLEFT", M, -86); f.nameLabel:SetText("Player")
    f.name = CreateFrame("EditBox", nil, f, "InputBoxTemplate"); f.name:SetSize(140, 20); f.name:SetPoint("TOPLEFT", 74, -82); f.name:SetAutoFocus(false); f.name:SetMaxLetters(64)
    f.name:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.postBtn = Btn("", 300 - 2 * M, 20, function() f.withText = not f.withText; f:Sync() end)
    f.postBtn:SetPoint("TOPLEFT", M, -112)
    f.status = Text(f, "GameFontHighlightSmall", "TOPLEFT", M, -142); f.status:SetPoint("TOPRIGHT", -M, -142); f.status:SetJustifyH("LEFT"); f.status:SetHeight(26); f.status:SetWordWrap(true); f.status:SetJustifyV("TOP")
    f.send = Btn("Send", 80, 22, function()
        -- (D53) the note the window named when it opened, not whichever note is current now
        local text = f:NoteText()
        if text == nil then f.status:SetText("|cffff6060That note was deleted: close this window and share again.|r"); return end
        local ok, info = ns.NotepadShare_Send(text, f.channel, (f.name:GetText() or ""):gsub("%s+", ""), f.withText)
        if ok then f:Hide() else f.status:SetText("|cffff6060" .. tostring(info) .. "|r") end
    end)
    f.send:SetPoint("BOTTOMLEFT", M, M)
    f.cancel = Btn("Cancel", 80, 22, function() f:Hide() end); f.cancel:SetPoint("LEFT", f.send, "RIGHT", G, 0)
    local x = CreateFrame("Button", nil, f); x:SetSize(16, 16); x:SetPoint("TOPRIGHT", -4, -4)
    x.xuiEdge = true   -- a title-bar close sits at the edge on purpose (#351)
    x.fs = x:CreateFontString(nil, "OVERLAY", "GameFontNormal"); x.fs:SetPoint("CENTER"); x.fs:SetText("x"); x:SetScript("OnClick", function() f:Hide() end)
    f.channel, f.withText = "PARTY", true
    -- the note this window shares: the one current when it opened (kept by its id in f.noteID); nil once that note is deleted
    function f:NoteText()
        if self.noteID ~= nil and ns.Notepad_TextOf then return ns.Notepad_TextOf(self.noteID) end
        return ns.Notepad_CurrentText and ns.Notepad_CurrentText() or ""
    end
    function f:Sync()
        local label = "?"
        for _, c in ipairs(CHANNELS) do if c[1] == self.channel then label = c[2] end end
        self.ch.fs:SetText(label .. "  (click to change)")
        local whisper = self.channel == "WHISPER"
        self.name:SetShown(whisper); self.nameLabel:SetShown(whisper)
        self.postBtn.fs:SetText((self.withText and "[x] " or "[  ] ") .. "Also post the text as chat lines (up to 6)")
        local t = self:NoteText() or ""
        self.what:SetText(Title(t) .. "  (" .. #t .. " characters)")
        self.status:SetText("XayaUI users are offered the whole note to save. A header line is always posted to chat.")
    end
    f:Hide()
    shareFrame = f
    return f
end

-- (Bonus 0.6.14) nothing of the sharing opens while the Notepad is off (ns.Notepad_On, Notepad.lua)
local function NotepadOn() return ns.Notepad_On == nil or ns.Notepad_On() end
function ns.NotepadShare_OpenShare()
    if not NotepadOn() then return end
    local f = BuildShare()
    local av = Available()
    local ok = false
    for _, c in ipairs(av) do if c[1] == f.channel then ok = true end end
    if not ok then f.channel = av[1] and av[1][1] or "WHISPER" end
    f.noteID = ns.Notepad_CurrentID and ns.Notepad_CurrentID() or nil   -- (D53)
    f:Sync(); f:Show()
end
-- the text the open Share window would send (nil: no window open, or its note was deleted; tests and the QA walkthrough)
function ns.NotepadShare_ShareText() if shareFrame and shareFrame:IsShown() then return shareFrame:NoteText() end end

-------------------------------------------------------------------------------
-- export / import window
-------------------------------------------------------------------------------
local ioFrame
local function BuildIO()
    if ioFrame then return ioFrame end
    local f = CreateFrame("Frame", "XayaUINoteIO", UIParent, "BackdropTemplate")
    f:SetSize(420, 320); f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true)
    f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(0.06, 0.06, 0.06, 0.95); f:SetBackdropBorderColor(0.2, 0.7, 1, 1)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal"); f.title:SetPoint("TOPLEFT", M, -M); f.title:SetText("Export / import notes")
    local function Btn(label, w, fn)
        local b = CreateFrame("Button", nil, f)
        b:SetSize(w, 20)
        b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(); b.bg:SetColorTexture(0.18, 0.18, 0.18, 0.95)
        b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(0.2, 0.7, 1, 0.35)
        b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.fs:SetPoint("CENTER"); b.fs:SetText(label)
        b:SetScript("OnClick", fn)
        return b
    end
    -- (the three mode buttons are one segmented row: 4 px seams; #351 phase 2 moved the rows to M / G)
    f.m1 = Btn("This note", 90, function() f:SetMode("one") end); f.m1:SetPoint("TOPLEFT", M, -34)
    f.m2 = Btn("All notes", 90, function() f:SetMode("all") end); f.m2:SetPoint("LEFT", f.m1, "RIGHT", 4, 0)
    f.m3 = Btn("Import", 90, function() f:SetMode("import") end); f.m3:SetPoint("LEFT", f.m2, "RIGHT", 4, 0)
    f.help = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.help:SetPoint("TOPLEFT", M, -(54 + G)); f.help:SetPoint("TOPRIGHT", -M, -(54 + G))
    f.help:SetJustifyH("LEFT"); f.help:SetTextColor(0.7, 0.7, 0.7); f.help:SetHeight(28); f.help:SetWordWrap(true); f.help:SetJustifyV("TOP")
    local sf = CreateFrame("ScrollFrame", "XayaUINoteIOScroll", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", M, -(54 + G + 28 + G)); sf:SetPoint("BOTTOMRIGHT", -28, M + 20 + G)   -- G under the help, G above the button
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetMaxLetters(0); eb:SetFontObject(ChatFontNormal or GameFontHighlight); eb:SetWidth(370)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnTextChanged", function(self) if sf.UpdateScrollChildRect then sf:UpdateScrollChildRect() end end)
    sf:SetScrollChild(eb)
    f.eb, f.sf = eb, sf
    f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.status:SetPoint("BOTTOMLEFT", M, M + 4); f.status:SetPoint("BOTTOMRIGHT", -140, M + 4); f.status:SetJustifyH("LEFT"); f.status:SetWordWrap(false)
    f.act = Btn("Select all", 90, function()
        if f.mode == "import" then
            local texts = ns.NotepadShare_Parse(f.eb:GetText())
            if #texts == 0 then f.status:SetText("|cffff6060Nothing to import.|r") return end
            local added, skipped = 0, 0
            for i, t in ipairs(texts) do
                if i > MAX_IMPORT then skipped = #texts - MAX_IMPORT; break end
                t = ns.NotepadShare_Clean(t, MaxChars())
                if t:match("%S") and ns.Notepad_AddNote and ns.Notepad_AddNote(t) then added = added + 1 end
            end
            f.status:SetText(("Imported %d note%s at the end of your list.%s"):format(added, added == 1 and "" or "s", skipped > 0 and (" " .. skipped .. " beyond the limit of " .. MAX_IMPORT .. " were skipped.") or ""))
            f.eb:SetText("")
        else
            f.eb:SetFocus(); f.eb:HighlightText()
            f.status:SetText("Press Ctrl+C to copy.")
        end
    end)
    f.act:SetPoint("BOTTOMRIGHT", -30, M)
    local x = CreateFrame("Button", nil, f); x:SetSize(16, 16); x:SetPoint("TOPRIGHT", -4, -4)
    x.xuiEdge = true   -- a title-bar close sits at the edge on purpose (#351)
    x.fs = x:CreateFontString(nil, "OVERLAY", "GameFontNormal"); x.fs:SetPoint("CENTER"); x.fs:SetText("x"); x:SetScript("OnClick", function() f:Hide() end)
    function f:SetMode(mode)
        self.mode = mode
        local function Tint(b, on) b.bg:SetColorTexture(on and 0.1 or 0.18, on and 0.45 or 0.18, on and 0.7 or 0.18, 0.95) end
        Tint(self.m1, mode == "one"); Tint(self.m2, mode == "all"); Tint(self.m3, mode == "import")
        self.status:SetText("")
        if mode == "import" then
            self.help:SetText("Paste an export block here (or any plain text, which becomes one note), then Import. Notes are added at the end of your list.")
            self.act.fs:SetText("Import")
            self.eb:SetText(""); self.eb:SetFocus()
        else
            local texts = (mode == "all") and (ns.Notepad_AllTexts and ns.Notepad_AllTexts() or {}) or { ns.Notepad_CurrentText and ns.Notepad_CurrentText() or "" }
            self.help:SetText("Select all, then Ctrl+C. Paste it anywhere to keep it; the Import tab reads it back.")
            self.act.fs:SetText("Select all")
            self.eb:SetText(ns.NotepadShare_Export(texts)); self.eb:SetCursorPosition(0)
        end
    end
    f:Hide()
    ioFrame = f
    return f
end

function ns.NotepadShare_OpenIO(mode)
    if not NotepadOn() then return end
    local f = BuildIO()
    f:Show(); f:SetMode(mode == "import" and "import" or (mode == "all" and "all" or "one"))
end

-------------------------------------------------------------------------------
-- the More menu (a small list under the toolbar button)
-------------------------------------------------------------------------------
local menu, catcher
function ns.NotepadShare_Menu(owner)
    if menu and menu:IsShown() then menu:Hide(); catcher:Hide() return end
    if not NotepadOn() then return end
    if not menu then
        catcher = CreateFrame("Button", nil, UIParent)
        catcher:SetAllPoints(UIParent); catcher:SetFrameStrata("FULLSCREEN"); catcher:Hide()
        menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG"); menu:SetSize(170, 4 * 20 + 6)
        menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        menu:SetBackdropColor(0.08, 0.08, 0.08, 0.97); menu:SetBackdropBorderColor(0.2, 0.7, 1, 1)
        catcher:SetScript("OnClick", function() menu:Hide(); catcher:Hide() end)
        local items = {
            { "Share this note...", function() ns.NotepadShare_OpenShare() end },
            { "Export this note...", function() ns.NotepadShare_OpenIO("one") end },
            { "Export all notes...", function() ns.NotepadShare_OpenIO("all") end },
            { "Import notes...", function() ns.NotepadShare_OpenIO("import") end },
        }
        for i, it in ipairs(items) do
            local b = CreateFrame("Button", nil, menu)
            b:SetHeight(20); b:SetPoint("TOPLEFT", 3, -3 - (i - 1) * 20); b:SetPoint("TOPRIGHT", -3, -3 - (i - 1) * 20)
            b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(0.2, 0.7, 1, 0.35)
            b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.fs:SetPoint("LEFT", 6, 0); b.fs:SetText(it[1])
            b:SetScript("OnClick", function() menu:Hide(); catcher:Hide(); it[2]() end)
        end
        menu:Hide()
    end
    menu:ClearAllPoints(); menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    catcher:Show(); menu:Show()
end

-------------------------------------------------------------------------------
-- events (V14, Bonus 0.6.12): CHAT_MSG_ADDON and the XUINOTE prefix only while "Accept notes shared by other XayaUI users" is on
-- (ns.NotepadShare_Sync: at login and when the switch changes); PLAYER_REGEN_ENABLED only while an offer waits for combat to end. Up to
-- 0.6.11 all three were registered at load: every addon message from every addon ran Handle, and XUINOTE parts were put together
-- with the switch off. The game has no call to take a prefix back (docs/reference/api/namespaces.md lists C_ChatInfo
-- RegisterAddonMessagePrefix and IsAddonMessagePrefixRegistered only), so a prefix registered while it was on stays until /reload; with
-- the event let go nothing of this file runs for it.
-------------------------------------------------------------------------------
local ev, prefixDone
local function OnEvent(_, e, ...)
    if e == "CHAT_MSG_ADDON" then
        Handle(...)
    elseif e == "PLAYER_REGEN_ENABLED" then
        WaitCombat(false)
        if #pending > 0 then ShowOffer() end
    end
end
local function Ev()
    if not ev then ev = CreateFrame("Frame"); ev:SetScript("OnEvent", OnEvent) end
    return ev
end
WaitCombat = function(on)
    if on then Ev():RegisterEvent("PLAYER_REGEN_ENABLED") elseif ev then ev:UnregisterEvent("PLAYER_REGEN_ENABLED") end
end
function ns.NotepadShare_Sync()
    local db = DB()
    -- (Bonus 0.6.14) the Notepad off: no shared note is listened for, whatever "Accept notes shared" says, and its windows close
    accepting = (db and db.acceptShares and db.enabled ~= false) and true or false
    if db and db.enabled == false then
        for _, name in ipairs({ "XayaUINoteOffer", "XayaUINoteShare", "XayaUINoteIO" }) do
            local f = _G[name]
            if f and f.Hide then f:Hide() end
        end
        if menu and menu:IsShown() then menu:Hide(); catcher:Hide() end
        wipe(pending)
        WaitCombat(false)
    end
    if accepting then
        if not prefixDone and C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            prefixDone = pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
        end
        Ev():RegisterEvent("CHAT_MSG_ADDON")
    else
        if ev then ev:UnregisterEvent("CHAT_MSG_ADDON") end
        wipe(assembling)   -- parts of notes still coming in are dropped
    end
end
if ns.AtLogin then ns.AtLogin(ns.NotepadShare_Sync)   -- (core Modules.lua: at PLAYER_LOGIN, or at once after it)
else
    local boot = CreateFrame("Frame")
    boot:RegisterEvent("PLAYER_LOGIN")
    boot:SetScript("OnEvent", function(self) self:UnregisterAllEvents(); ns.NotepadShare_Sync() end)
end
