-------------------------------------------------------------------------------
-- Chat/Options.lua : the Chat Panel settings page (QoL UI Updates > Chat Panel). Tabs: General, Chat Bar, Look, Behavior, Parts,
-- Filters, History, Sounds, Privacy. Every change applies at once. Own code. UNTESTED in game.
-------------------------------------------------------------------------------
local ADDON, ns = ...
local C = ns.Chat

local OUTLINE = { none = "None", outline = "Outline", thick = "Thick outline" }
local OUTLINE_ORDER = { "none", "outline", "thick" }
local TAB_OUTLINE = { none = "None", outline = "Outline", thick = "Thick outline", shadow = "Shadow" }
local TAB_OUTLINE_ORDER = { "none", "outline", "thick", "shadow" }

function C.OpenSettings(tab)
    if ns.UI and ns.UI.ChatPanel then ns.UI.ChatPanel(tab) end
end

local soundCache
local function SoundChoices()
    if not soundCache then
        local values, order = { [""] = "(none)" }, { "" }
        for _, e in ipairs((ns.BuildSoundList and ns.BuildSoundList()) or {}) do
            local k = tostring(e.source) .. "|" .. tostring(e.value)
            values[k] = e.label; order[#order + 1] = k
        end
        soundCache = { values, order }
    end
    return soundCache[1], soundCache[2]
end

function ns.BuildChatTab(Notify)
    local function S() return ns.chat2 or {} end
    local function Re() C.Refresh(); if Notify then Notify() end end
    local function note(text, order, hidden)
        return { type = "description", order = order, width = "full", fontSize = "medium", name = text, hidden = hidden }
    end
    local function tog(name, field, order, desc, hidden)
        return { type = "toggle", name = name, desc = desc, order = order, width = "full", hidden = hidden,
            get = function() return S()[field] and true or false end,
            set = function(_, v) local s = ns.chat2; if s then s[field] = v and true or false end; Re() end }
    end
    local function rng(name, field, order, min, max, desc, step, hidden)
        return { type = "range", name = name, desc = desc, order = order, min = min, max = max, step = step or 1, hidden = hidden,
            get = function() return S()[field] end,
            set = function(_, v) local s = ns.chat2; if s then s[field] = v end; Re() end }
    end
    local function sel(name, field, order, values, sorting, desc, hidden)
        return { type = "select", name = name, desc = desc, order = order, values = values, sorting = sorting, hidden = hidden,
            get = function() return S()[field] end,
            set = function(_, v) local s = ns.chat2; if s then s[field] = v end; Re() end }
    end
    local function col(name, prefix, order, desc, hidden)   -- stored as <prefix>R / G / B and <prefix>A (percent)
        return { type = "color", name = name, desc = desc, order = order, hasAlpha = true, hidden = hidden,
            get = function() local s = S(); return s[prefix .. "R"] or 0, s[prefix .. "G"] or 0, s[prefix .. "B"] or 0, (tonumber(s[prefix .. "A"]) or 100) / 100 end,
            set = function(_, r, g, b, a)
                local s = ns.chat2; if not s then return end
                s[prefix .. "R"], s[prefix .. "G"], s[prefix .. "B"] = r, g, b
                if a then s[prefix .. "A"] = math.floor(a * 100 + 0.5) end
                Re()
            end }
    end
    local function col3(name, prefix, order, desc)           -- no opacity
        return { type = "color", name = name, desc = desc, order = order, hasAlpha = false,
            get = function() local s = S(); return s[prefix .. "R"] or 1, s[prefix .. "G"] or 1, s[prefix .. "B"] or 1, 1 end,
            set = function(_, r, g, b) local s = ns.chat2; if not s then return end; s[prefix .. "R"], s[prefix .. "G"], s[prefix .. "B"] = r, g, b; Re() end }
    end
    local function fontSel(name, field, order)
        return { type = "select", name = name, order = order,
            values = function() local v = ns.FontList(); return v end,
            sorting = function() local _, o = ns.FontList(); return o end,
            get = function() return S()[field] end,
            set = function(_, v) local s = ns.chat2; if s then s[field] = v end; Re() end }
    end
    local function themeOn() return S().useTheme end

    ---------------------------------------------------------------------------------------------------------------------------
    local general = { type = "group", name = "General", order = 1, args = {
        blocked = { type = "description", order = 1, width = "full", fontSize = "medium",
            hidden = function() return C.BlockedReason() == nil end,
            name = function() return "|cffff5555Blocked:|r " .. tostring(C.BlockedReason()) end },
        intro = note("Chat Panel restyles Blizzard's own chat window in place and gives it one container: the tabs, the text, and the line you type in are all inside the pane, and the Chat Bar is part of the same block. Turning it off fully takes effect after /reload. /xui chat shows what ran and what failed.", 2),
        secretNote = note("|cffaaaaaaProtected messages:|r in some instance states the game marks chat text as secret. Addons cannot read or change that text, so the spam filters and links skip those lines, the history lists them as protected, and everything else (position, look, fade, sounds) still works.", 3),
        enabled = { type = "toggle", name = "Enable Chat Panel", order = 4, width = "full",
            get = function() return S().enabled and true or false end,
            set = function(_, v) local s = ns.chat2; if s then s.enabled = v and true or false end; Re() end },
        place = { type = "group", name = "Place and size", order = 10, inline = true, args = {
            w = rng("Width (pixels)", "width", 1, 220, 1000, "The width of the whole block: pane and Chat Bar."),
            h = rng("Height of the chat pane (pixels)", "height", 2, 90, 800, "Tabs, text and input line together. The Chat Bar is added to this."),
            move = { type = "execute", name = "Move or resize the chat", order = 3, desc = "Shows a blue box over the chat: drag it to move, drag its top-right corner to resize. Run it again (or /xui chat move) to finish.",
                func = function() C.ToggleMover() end },
            reset = { type = "execute", name = "Reset position and size", order = 4, func = function() C.Command("reset"); if Notify then Notify() end end },
        } },
        theme = { type = "group", name = "XayaUI theme", order = 20, inline = true, args = {
            use = tog("Use the XayaUI theme for the chat's colors and font", "useTheme", 1,
                "When on, the background, border, tabs, input line, bar, and the chat font follow your selected XayaUI theme. The opacity sliders still apply on top. Turn it off to use the colors you pick under Look."),
        } },
    } }

    ---------------------------------------------------------------------------------------------------------------------------
    local barArgs = {
        on = tog("Show the Chat Bar", "barOn", 1, "A row of data blocks that is part of the chat: it is as wide as the chat, snapped to it, and collapses with it."),
        side = sel("Place the bar", "barSide", 2, { TOP = "Above the chat", BOTTOM = "Below the chat" }, { "BOTTOM", "TOP" }),
        h = rng("Bar height (pixels)", "barH", 3, 14, 60),
        gap = rng("Gap between the bar and the chat (pixels)", "barGap", 4, 0, 20),
        n = rng("Number of blocks", "barSlots", 5, 1, C.MAX_SLOTS),
        sizing = sel("Block widths", "barSizing", 6, { EVEN = "Equal widths", AUTO = "Follow the text (blocks marked Fill take the rest)" }, { "EVEN", "AUTO" }),
        textSize = rng("Text size", "barTextSize", 7, 8, 30),
        bg = tog("Bar background", "barBgOn", 8),
        bgCol = col("Background color", "barBg", 9),
        bd = tog("Bar border", "barBorderOn", 10),
        bdCol = col("Border color", "barBorder", 11),
        text = col3("Text color", "barText", 12),
        value = col3("Number color (friends and similar)", "barValue", 13, "The color of the numbers in blocks such as Friends."),
        labels = tog("Put the name in front of the character stats", "barLabels", 14),
        hover = tog("Highlight the block under the mouse", "barHover", 15),
        c24 = tog("24-hour clock", "barClock24", 16),
        loc = tog("Use the computer's time (off = the realm's time)", "barLocalTime", 17),
    }
    for i = 1, C.MAX_SLOTS do
        local function hiddenSlot() return i > (tonumber(S().barSlots) or 3) end
        barArgs["slot" .. i] = { type = "group", name = "Block " .. i, order = 30 + i, inline = true, hidden = hiddenSlot, args = {
            type = { type = "select", name = "Shows", order = 1,
                values = function() local v = {}; for _, t in ipairs(C.Bar_Types()) do v[t[1]] = t[2] end; return v end,
                sorting = function() local o = {}; for _, t in ipairs(C.Bar_Types()) do o[#o + 1] = t[1] end; return o end,
                get = function() return S()["barType" .. i] end,
                set = function(_, v) local s = ns.chat2; if s then s["barType" .. i] = v end; Re() end },
            align = { type = "select", name = "Align text", order = 2, values = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" }, sorting = { "LEFT", "CENTER", "RIGHT" },
                get = function() return S()["barAlign" .. i] or "CENTER" end,
                set = function(_, v) local s = ns.chat2; if s then s["barAlign" .. i] = v end; Re() end },
            fill = { type = "toggle", name = "Fill", order = 3, desc = "With 'Follow the text' widths: this block takes the space that is left.",
                hidden = function() return S().barSizing ~= "AUTO" end,
                get = function() return S()["barFill" .. i] and true or false end,
                set = function(_, v) local s = ns.chat2; if s then s["barFill" .. i] = v and true or false end; Re() end },
            custom = { type = "input", name = "Your text", order = 4, width = "full",
                hidden = function() return S()["barType" .. i] ~= "CUSTOM" end,
                get = function() return S()["barCustom" .. i] or "" end,
                set = function(_, v) local s = ns.chat2; if s then s["barCustom" .. i] = v or "" end; Re() end },
        } }
    end
    local bar = { type = "group", name = "Chat Bar", order = 2, args = barArgs }

    ---------------------------------------------------------------------------------------------------------------------------
    local function TexValues()
        local v = { [""] = "(none)" }
        for _, t in ipairs(C.BUILTIN_TEX) do v[t[1]] = t[2] end
        local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
        if lsm then for n in pairs(lsm:HashTable("background")) do v["lsm:" .. n] = n end end
        return v
    end
    local function TexOrder()
        local o = { "" }
        for _, t in ipairs(C.BUILTIN_TEX) do o[#o + 1] = t[1] end
        local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
        if lsm then
            local names = {}
            for n in pairs(lsm:HashTable("background")) do names[#names + 1] = n end
            table.sort(names)
            for _, n in ipairs(names) do o[#o + 1] = "lsm:" .. n end
        end
        return o
    end
    local look = { type = "group", name = "Look", order = 3, args = {
        themeNote = note("|cffaaaaaaWith 'Use the XayaUI theme' on (General tab) the colors and font below are ignored; only the opacity sliders still apply.|r", 1, function() return not themeOn() end),
        bgHdr = { type = "header", name = "Background", order = 10 },
        bg = tog("Draw a background", "bgOn", 11),
        bgCol = col("Background color", "bg", 12),
        tex = { type = "select", name = "Background texture", order = 13, values = TexValues, sorting = TexOrder,
            get = function() return S().bgTex or "" end,
            set = function(_, v) local s = ns.chat2; if s then s.bgTex = v end; Re() end },
        tile = tog("Tile the texture", "bgTile", 14),
        texA = rng("Texture opacity (%)", "bgTexA", 15, 0, 100, nil, 5),
        bd = tog("Border", "borderOn", 16),
        bdCol = col("Border color", "border", 17),
        fontHdr = { type = "header", name = "Chat text", order = 20 },
        font = fontSel("Font", "font", 21),
        fontSize = rng("Font size", "fontSize", 22, 8, 32),
        outline = sel("Outline", "fontOutline", 23, OUTLINE, OUTLINE_ORDER),
        inHdr = { type = "header", name = "Input line", order = 30 },
        inBg = col("Input background", "inputBg", 31),
        inBd = col("Input border", "inputBd", 32),
        inFocus = tog("Border takes the selected-tab color while typing", "inputFocusBd", 33),
        hint = tog("Show a hint in the empty input line", "inputHint", 34),
        hintText = { type = "input", name = "Hint text", order = 35,
            get = function() return S().inputHintText or "" end,
            set = function(_, v) local s = ns.chat2; if s then s.inputHintText = v or "" end; Re() end },
        inH = rng("Input line height (pixels)", "inputH", 36, 18, 60),
        tabHdr = { type = "header", name = "Tabs", order = 40 },
        tabs = tog("Show the tab row", "tabsShow", 41, "Hiding the tabs also hides the way to switch chat windows."),
        tabH = rng("Tab height (pixels)", "tabHeight", 42, 16, 40),
        tabFont = fontSel("Tab font", "tabFont", 43),
        tabSize = rng("Tab font size", "tabFontSize", 44, 8, 24),
        tabOutline = sel("Tab outline", "tabOutline", 45, TAB_OUTLINE, TAB_OUTLINE_ORDER),
        tabText = col3("Tab text color", "tabText", 46),
        tabSel = col3("Selected tab text color", "tabSel", 47, "Also the border color of the input line while you type."),
        tabBgOn = tog("Flat tab backgrounds", "tabBgOn", 48),
        tabBg = col("Tab background", "tabBg", 49),
        tabSelBg = col("Selected tab background", "tabSelBg", 50),
    } }

    ---------------------------------------------------------------------------------------------------------------------------
    local behavior = { type = "group", name = "Behavior", order = 4, args = {
        collapse = { type = "toggle", name = "Chat hidden (collapsed)", order = 1, width = "full",
            desc = "Same as the arrow on the Chat Bar. Only the bar (or the small arrow) stays on screen.",
            get = function() return S().collapsed and true or false end,
            set = function(_, v) C.SetCollapsed(v); if Notify then Notify() end end },
        fadeHdr = { type = "header", name = "Auto-hide / fade", order = 10 },
        fadeNote = note("After a while with no mouse over the chat, nothing typed, and no new message, the chat fades to the opacity below (0 = fully hidden). The mouse over it, typing, or a new message brings it back.", 11),
        fade = tog("Fade the chat when it is idle", "fadeOn", 12),
        after = rng("Seconds before it fades", "fadeAfter", 13, 2, 120),
        to = rng("Opacity when faded (%)", "fadeTo", 14, 0, 100, "0 hides it completely.", 5),
        secs = rng("Fade duration (seconds)", "fadeSeconds", 15, 0.1, 3, nil, 0.1),
        wake = tog("A new message brings the chat back", "fadeWake", 16),
        bar = tog("Fade the Chat Bar too", "fadeBar", 17),
        textHdr = { type = "header", name = "Old lines", order = 20 },
        textFade = tog("Fade old lines away", "textFade", 21, "The game's own per-line fade. Off keeps every line visible until it scrolls out."),
        textAfter = rng("Seconds a line stays visible", "textFadeAfter", 22, 10, 600, nil, 10, function() return not S().textFade end),
    } }

    ---------------------------------------------------------------------------------------------------------------------------
    local parts = { type = "group", name = "Parts", order = 5, args = {
        n = note("Blizzard's own extra pieces around the chat.", 1),
        stripHdr = { type = "header", name = "Button strip (menu, channels, voice)", order = 10 },
        strip = sel("Button strip", "stripMode", 11, { HIDE = "Hidden", LEFT = "Left of the chat", RIGHT = "Right of the chat" }, { "HIDE", "LEFT", "RIGHT" }),
        stripX = rng("Strip: move right (pixels)", "stripX", 12, -300, 300, nil, 1, function() return S().stripMode == "HIDE" end),
        stripY = rng("Strip: move up (pixels)", "stripY", 13, -300, 300, nil, 1, function() return S().stripMode == "HIDE" end),
        socialHdr = { type = "header", name = "Social / quick-join button", order = 20 },
        social = sel("Social button", "socialMode", 21, { HIDE = "Hidden", SHOW = "Shown above the chat" }, { "HIDE", "SHOW" },
            "The round button with a number that the game anchors near the chat."),
        socialX = rng("Social button: move right (pixels)", "socialX", 22, -300, 300, nil, 1, function() return S().socialMode ~= "SHOW" end),
        socialY = rng("Social button: move up (pixels)", "socialY", 23, -300, 300, nil, 1, function() return S().socialMode ~= "SHOW" end),
        miscHdr = { type = "header", name = "Other", order = 30 },
        scroll = sel("Scroll bar", "scrollBar", 31, { HIDE = "Hidden", SHOW = "Shown" }, { "HIDE", "SHOW" }),
        inset = rng("Text inset from the edge (pixels)", "textInset", 32, 0, 30),
        histBtn = tog("Show the small history button in the chat's corner", "histButton", 33),
    } }

    ---------------------------------------------------------------------------------------------------------------------------
    local filters = { type = "group", name = "Filters", order = 6, args = {
        n = note("These work on public messages (say, yell, emotes, channels) and whispers. Your own messages are never filtered. Protected (secret) lines are never touched.", 1),
        rep = tog("Hide repeated messages", "spamRepeat", 2, "Hides the same message from the same player when it comes again within the time below. Whispers are not checked."),
        repSec = rng("Repeat window (seconds)", "spamSeconds", 3, 5, 300, nil, 5, function() return not S().spamRepeat end),
        phrasesHdr = { type = "header", name = "Blocked phrases", order = 10 },
        phrases = { type = "input", name = "Your blocked-phrase list (one per line)", order = 11, width = "full", multiline = 6,
            desc = "A message containing any of these (ignoring capital letters) is hidden.",
            get = function() return S().spamPhrases or "" end,
            set = function(_, v) local s = ns.chat2; if s then s.spamPhrases = v or "" end; Re() end },
        word = tog("Match whole words only", "spamWord", 12, "'gold' would then not match 'golden'."),
        stats = { type = "description", order = 13, width = "full", name = function() return "Hidden this session: " .. tostring(C.stats.suppressed) end },
        clickHdr = { type = "header", name = "Quick ignore", order = 20 },
        click = tog("Ctrl + right-click a player's name in chat to ignore them", "ignoreClick", 21),
        linkHdr = { type = "header", name = "Links", order = 30 },
        links = tog("Make web addresses clickable", "links", 31, "Click one to open a box with the address selected; press Ctrl+C to copy it."),
        linkCol = col3("Link color", "link", 32),
    } }

    local history = { type = "group", name = "History", order = 7, args = {
        n = note("The history pane lists recent messages as plain text you can select and copy. It is kept in memory only: nothing is written to disk, and it is gone when you log out or reload.", 1),
        on = tog("Keep recent messages for the history pane", "histOn", 2),
        size = rng("Messages kept", "histSize", 3, 20, 2000, nil, 10, function() return not S().histOn end),
        open = { type = "execute", name = "Open the history pane", order = 4, func = function() C.History_Toggle() end },
    } }

    ---------------------------------------------------------------------------------------------------------------------------
    local sounds = { type = "group", name = "Sounds", order = 8, args = {
        n = note("A sound for each chat tab. It plays when a message arrives for a kind of message that tab shows. Your own messages never play a sound. A tab keeps the kinds it shows in Blizzard's own chat settings (right-click the tab).", 1),
        on = tog("Play tab sounds", "soundsOn", 2),
        combat = tog("Also play them in combat", "soundsInCombat", 3),
    } }
    for i = 1, 10 do
        local function cfg(create)
            local s = ns.chat2; if not s then return nil end
            s.sounds = s.sounds or {}
            if create and not s.sounds[i] then s.sounds[i] = { enabled = false, source = "kit", value = "", channel = "Master" } end
            return s.sounds[i]
        end
        sounds.args["tab" .. i] = { type = "group", order = 10 + i, inline = true,
            name = function() local n = GetChatWindowInfo and GetChatWindowInfo(i); return "Tab " .. i .. ((type(n) == "string" and n ~= "") and (": " .. n) or "") end,
            hidden = function() local n = GetChatWindowInfo and GetChatWindowInfo(i); return not (type(n) == "string" and n ~= "") end,
            args = {
                en = { type = "toggle", name = "Play a sound", order = 1,
                    get = function() local c = cfg(); return c and c.enabled and true or false end,
                    set = function(_, v) cfg(true).enabled = v and true or false end },
                snd = { type = "select", name = "Sound", order = 2, width = "double",
                    values = function() local v = SoundChoices(); return v end, sorting = function() local _, o = SoundChoices(); return o end,
                    get = function() local c = cfg(); return (c and c.value and c.value ~= "") and (tostring(c.source) .. "|" .. tostring(c.value)) or "" end,
                    set = function(_, k)
                        local c = cfg(true)
                        if k == "" then c.value = "" else c.source, c.value = k:match("^(%w+)|(.*)$") end
                    end },
                chan = { type = "select", name = "Sound channel", order = 3,
                    values = { Master = "Master", SFX = "Sound effects", Music = "Music", Ambience = "Ambience", Dialog = "Dialog" }, sorting = { "Master", "SFX", "Music", "Ambience", "Dialog" },
                    get = function() local c = cfg(); return c and c.channel or "Master" end,
                    set = function(_, v) cfg(true).channel = v end },
                test = { type = "execute", name = "Test", order = 4, func = function() local c = cfg(); if c and ns.PlaySoundPreview then ns.PlaySoundPreview(c) end end },
            } }
    end

    local privacy = ns.ChatPrivacy_Options and ns.ChatPrivacy_Options(Notify) or nil
    if privacy then privacy.order = 9; privacy.name = "Privacy" end

    return { type = "group", name = "Chat Panel", order = 1, childGroups = "tab",
        args = { general = general, bar = bar, look = look, behavior = behavior, parts = parts, filters = filters, history = history, sounds = sounds, privacy = privacy } }
end
