-------------------------------------------------------------------------------
-- Options.lua (XayaUI Chat) : the Chat Panel settings (Chat > Chat Panel). The Chat Panel node holds the panel-wide switches; its parts
-- are nodes under it in the left pane (Layout, Appearance, Chat Data Panel, Fade and hide, Filters, History, Sounds, Privacy), and each
-- part's sections are tabs (ns.SectionTabs, Modules.lua; Xaya, 2026-11-03). Every change applies at once. Own code. UNTESTED in game.
-------------------------------------------------------------------------------
local ADDON, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (this addon depends on it: ## Dependencies: XayaUI)
local C = ns.Chat

local OUTLINE = { none = "None", outline = "Outline", thick = "Thick outline" }
local OUTLINE_ORDER = { "none", "outline", "thick" }
local TAB_OUTLINE = { none = "None", outline = "Outline", thick = "Thick outline", shadow = "Shadow" }
local TAB_OUTLINE_ORDER = { "none", "outline", "thick", "shadow" }

-- part = a part under Chat Panel ("layout", "look", "bar", ...); section = a tab inside it ("tab_<header key>", e.g. "tab_blocksHdr")
-- (Chat 0.6.13: the Chat Panel's page is in the settings window's Blizzard UI Reskin tab, module "reskin"; Xaya 2026-11-05)
function C.OpenSettings(part, section)
    if part and section then ns.OpenSettingsPage("reskin", "chatpanel", part, section)
    elseif part then ns.OpenSettingsPage("reskin", "chatpanel", part)
    else ns.OpenSettingsPage("reskin", "chatpanel") end
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
    if C.EnsureDefaults then C.EnsureDefaults() end   -- the page shows the defaults even while the Chat Panel is saved off (V14: not built at login then)
    local function S() return ns.chat2 or {} end
    local function Re(flash)
        C.Refresh()
        if flash and C.Locate then C.Locate({ flash }, 3) end      -- outline the piece the setting changes, so the change can be seen
        if Notify then Notify() end
    end
    local function note(text, order, hidden)
        return { type = "description", order = order, width = "full", fontSize = "medium", name = text, hidden = hidden }
    end
    local function tog(name, field, order, desc, hidden, flash)
        return { type = "toggle", name = name, desc = desc, order = order, width = "full", hidden = hidden,
            get = function() return S()[field] and true or false end,
            set = function(_, v) local s = ns.chat2; if s then s[field] = v and true or false end; Re(flash) end }
    end
    local function rng(name, field, order, min, max, desc, step, hidden, flash)
        return { type = "range", name = name, desc = desc, order = order, min = min, max = max, step = step or 1, hidden = hidden,
            get = function() return S()[field] end,
            set = function(_, v) local s = ns.chat2; if s then s[field] = v end; Re(flash) end }
    end
    local function sel(name, field, order, values, sorting, desc, hidden, flash)
        return { type = "select", name = name, desc = desc, order = order, values = values, sorting = sorting, hidden = hidden,
            get = function() return S()[field] end,
            set = function(_, v) local s = ns.chat2; if s then s[field] = v end; Re(flash) end }
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
    -- Tabs, in the order you think about the chat: where it is, how it looks, the bar, when it hides, what it filters, then the extras.
    ---------------------------------------------------------------------------------------------------------------------------
    local function hdr(name, order, desc) return { type = "header", name = name, order = order, desc = desc } end
    local noStrip = function() return S().stripMode == "HIDE" end
    local noSocial = function() return S().socialMode ~= "SHOW" end

    -- 1. LAYOUT -------------------------------------------------------------------------------------------------------------
    local layout = { type = "group", name = "Layout", order = 1, args = {
        blocked = { type = "description", order = 1, width = "full", fontSize = "medium",
            hidden = function() return C.BlockedReason() == nil end,
            name = function() return "|cffff5555Blocked:|r " .. tostring(C.BlockedReason()) end },
        intro = note("Chat Panel restyles Blizzard's own chat window in place and puts it in one block: the tabs, the text, and the line you type in are inside the pane, and the Chat Data Panel is part of the same block. /xui chat shows what ran and what failed.", 2),
        enabled = { type = "toggle", name = "Enable Chat Panel", order = 3, width = "full",
            desc = "Off gives Blizzard's chat back as the game draws it, and nothing of the Chat Panel runs. A few hooks it placed in the game's chat while it was on stay until you /reload, but they do nothing.",
            get = function() return S().enabled and true or false end,
            set = function(_, v) local s = ns.chat2; if s then s.enabled = v and true or false end; Re() end },
        theme = tog("Use the XayaUI theme for the chat's colors and font", "useTheme", 4,
            "When on, the background, border, tabs, input line, bar, and the chat font follow your selected XayaUI theme (Appearance colors are then ignored; opacity sliders still apply)."),

        posHdr = hdr("Position and size", 10),
        w = rng("Width (pixels)", "width", 11, 220, 1000, "The width of the chat pane (with the Chat Data Panel above or below, the whole block)."),
        h = rng("Height of the chat pane (pixels)", "height", 12, 90, 800, "Tabs, text and input line together. A Chat Data Panel above or below is added to this."),
        move = { type = "execute", name = "Move or resize the chat", order = 13, desc = "Shows a box over the chat: drag it to move, drag its top-right corner to resize. Run it again (or /xui chat move) to finish.",
            func = function() C.ToggleMover() end },
        reset = { type = "execute", name = "Reset position and size", order = 14, func = function() C.Command("reset"); if Notify then Notify() end end },

        insideHdr = hdr("Inside the pane", 20),
        tabs = tog("Show the tab row", "tabsShow", 21, "Hiding the tabs also hides the way to switch chat windows."),
        tabH = rng("Tab height (pixels)", "tabHeight", 22, 16, 40, nil, 1, nil, "tabs"),
        inH = rng("Input line height (pixels)", "inputH", 23, 18, 60, nil, 1, nil, "input"),
        inset = rng("Text inset from the edge (pixels)", "textInset", 24, 2, 30, nil, 1, nil, "text"),
        wrapIndent = tog("Indent wrapped lines", "wrapIndent", 25,
            "When a message is longer than one line, the lines after the first start a little further in, so you can see where each message begins. The game's own chat does this.", nil, "text"),
        ownScroll = tog("Chat Panel scroll bar (slow scrolling)", "scrollOwn", 26,
            "A slim bar right of the text. Each arrow click moves one line; hold an arrow to keep scrolling at the speed below. Drag the thumb, or click above or below it to move a page.", nil, "ownscroll"),
        scrollSpeed = rng("Scroll bar: lines per second while an arrow is held", "scrollSpeed", 27, 1, 30, nil, 1, function() return not S().scrollOwn end, "ownscroll"),
        scrollW = rng("Scroll bar width (pixels)", "scrollW", 28, 6, 20, nil, 1, function() return not S().scrollOwn end, "ownscroll"),

        piecesHdr = hdr("Blizzard's own pieces", 30, "The button strip (menu, channels, voice), the round social button, the scroll bar, and the back-to-newest arrow."),
        strip = sel("Blizzard button strip", "stripMode", 31, { HIDE = "Hidden", LEFT = "Left of chat", RIGHT = "Right of chat" }, { "HIDE", "LEFT", "RIGHT" },
            "The column of small buttons beside the chat: chat menu, channels, voice.", nil, "strip"),
        social = sel("Social button", "socialMode", 32, { HIDE = "Hidden", SHOW = "Above the chat" }, { "HIDE", "SHOW" },
            "The round button with a number that the game anchors near the chat.", nil, "social"),
        scroll = sel("Blizzard's scroll bar", "scrollBar", 33, { HIDE = "Hidden", SHOW = "Shown" }, { "HIDE", "SHOW" },
            "Used only while the Chat Panel scroll bar (above) is off.", function() return S().scrollOwn end, "scroll"),
        toBottom = sel("Back-to-newest arrow", "toBottom", 34, { SHOW = "Shown", HIDE = "Hidden" }, { "SHOW", "HIDE" },
            "The small arrow that appears when you scroll up; it jumps to the newest message.", nil, "tobottom"),
        stripX = rng("Button strip: move right", "stripX", 35, -600, 600, nil, 1, noStrip, "strip"),
        stripY = rng("Button strip: move up", "stripY", 36, -600, 600, nil, 1, noStrip, "strip"),
        socialX = rng("Social button: move right", "socialX", 37, -600, 600, nil, 1, noSocial, "social"),
        socialY = rng("Social button: move up", "socialY", 38, -600, 600, nil, 1, noSocial, "social"),

        locate = { type = "execute", name = "Show me where each piece is", order = 39, width = "double",
            desc = "Outlines and labels every piece of the chat for 8 seconds, including pieces that are hidden.",
            func = function() C.Locate(nil, 8) end },

        noteHdr = hdr("Protected messages", 90),
        secretNote = note("|cffaaaaaaIn some instance states the game marks chat text as secret. Addons cannot read or change that text, so the filters and links skip those lines and the history lists them as protected. Position, look, fade and sounds still work.|r", 91),
    } }

    -- 2. APPEARANCE ---------------------------------------------------------------------------------------------------------
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
    local look = { type = "group", name = "Appearance", order = 2, args = {
        themeNote = note("|cffaaaaaaThe XayaUI theme is on (switch on the Chat Panel page): the colors and fonts below are ignored; only the opacity sliders still apply.|r", 1, function() return not themeOn() end),
        bgHdr = hdr("Background and border", 10),
        bg = tog("Draw a background", "bgOn", 11),
        bgCol = col("Background color", "bg", 12),
        bd = tog("Draw a border", "borderOn", 13),
        bdCol = col("Border color", "border", 14),
        tex = { type = "select", name = "Background texture", order = 15, values = TexValues, sorting = TexOrder,
            get = function() return S().bgTex or "" end,
            set = function(_, v) local s = ns.chat2; if s then s.bgTex = v end; Re() end },
        texA = rng("Texture opacity (%)", "bgTexA", 16, 0, 100, nil, 5),
        tile = tog("Tile the texture", "bgTile", 17),

        fontHdr = hdr("Chat text", 20),
        font = fontSel("Font", "font", 21),
        outline = sel("Outline", "fontOutline", 22, OUTLINE, OUTLINE_ORDER),
        fontSize = rng("Font size", "fontSize", 23, 8, 32),

        tabHdr = hdr("Tabs", 30, "The tab row's height and whether it shows are under Layout > Inside the pane."),
        tabFont = fontSel("Tab font", "tabFont", 31),
        tabOutline = sel("Tab outline", "tabOutline", 32, TAB_OUTLINE, TAB_OUTLINE_ORDER),
        tabSize = rng("Tab font size", "tabFontSize", 33, 8, 24),
        tabText = col3("Tab text color", "tabText", 34),
        tabSel = col3("Selected tab text color", "tabSel", 35, "Also the border color of the input line while you type."),
        tabBgOn = tog("Flat tab backgrounds", "tabBgOn", 36),
        tabBg = col("Tab background", "tabBg", 37),
        tabSelBg = col("Selected tab background", "tabSelBg", 38),

        inHdr = hdr("Input line", 40),
        inBg = col("Input background", "inputBg", 41),
        inBd = col("Input border", "inputBd", 42),
        inFocus = tog("Border takes the selected-tab color while typing", "inputFocusBd", 43),
        hint = tog("Show a hint in the empty input line", "inputHint", 44),
        hintText = { type = "input", name = "Hint text", order = 45,
            get = function() return S().inputHintText or "" end,
            set = function(_, v) local s = ns.chat2; if s then s.inputHintText = v or "" end; Re() end },
    } }

    -- 3. CHAT BAR -----------------------------------------------------------------------------------------------------------
    local barArgs = {
        on = tog("Show the Chat Data Panel", "barOn", 1, "Data blocks that are part of the chat: a row above or below it as wide as the chat, or a strip left or right of it as tall as the chat; snapped to it, and it collapses with it."),
        barHdr = hdr("Position", 5),
        side = sel("Place the panel", "barSide", 6, { TOP = "Above the chat", BOTTOM = "Below the chat", LEFT = "Left of the chat", RIGHT = "Right of the chat" }, { "BOTTOM", "TOP", "LEFT", "RIGHT" }, nil, nil, "bar"),
        sizing = sel("Block widths", "barSizing", 7, { EVEN = "Equal", AUTO = "Follow the text" }, { "EVEN", "AUTO" },
            "Equal: every block is the same width. Follow the text: each block is as wide as its text; blocks marked Fill take the space that is left."),
        h = rng("Panel height (pixels)", "barH", 8, 14, 60, nil, 1, function() local v = S().barSide; return v == "LEFT" or v == "RIGHT" end, "bar"),
        w = (function() local o = rng("Panel width (pixels)", "barW", 8.5, 40, 200, "Left or right of the chat: the strip is as tall as the chat window.", 1, function() local v = S().barSide; return not (v == "LEFT" or v == "RIGHT") end, "bar"); o.get = function() return tonumber(S().barW) or 90 end; return o end)(),
        gap = rng("Gap between the panel and the chat (pixels)", "barGap", 9, 0, 20, nil, 1, nil, "bar"),

        blocksHdr = hdr("Blocks", 10, "Each block shows one piece of data. Right-click a block on screen to open this page."),
        n = rng("Number of blocks", "barSlots", 11, 1, C.MAX_SLOTS),
    }
    for i = 1, C.MAX_SLOTS do
        local function hiddenSlot() return i > (tonumber(S().barSlots) or 3) end
        barArgs["slot" .. i] = { type = "group", name = "Block " .. i, order = 20 + i, inline = true, hidden = hiddenSlot, args = {
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
    barArgs.lookHdr = hdr("Look", 40)
    barArgs.textSize = rng("Text size", "barTextSize", 41, 8, 30)
    barArgs.text = col3("Text color", "barText", 42)
    barArgs.value = col3("Number color (friends and similar)", "barValue", 43, "The color of the numbers in blocks such as Friends.")
    barArgs.bg = tog("Panel background", "barBgOn", 44)
    barArgs.bgCol = col("Background color", "barBg", 45)
    barArgs.bd = tog("Panel border", "barBorderOn", 46)
    barArgs.bdCol = col("Border color", "barBorder", 47)
    barArgs.hover = tog("Highlight the block under the mouse", "barHover", 48)
    barArgs.dataHdr = hdr("Data options", 50)
    barArgs.c24 = tog("24-hour clock", "barClock24", 51)
    barArgs.loc = tog("Use the computer's time (off = the realm's time)", "barLocalTime", 52)
    barArgs.labels = tog("Put the name in front of the character stats", "barLabels", 53)
    local bar = { type = "group", name = "Chat Data Panel", order = 3, args = barArgs }

    -- 4. FADE AND HIDE ------------------------------------------------------------------------------------------------------
    local behavior = { type = "group", name = "Fade and hide", order = 4, args = {
        hideHdr = hdr("Hide the chat", 1),
        collapse = { type = "toggle", name = "Chat hidden (collapsed)", order = 2, width = "full",
            desc = "Same as the arrow on the Chat Data Panel. Only the panel (or the small arrow) stays on screen.",
            get = function() return S().collapsed and true or false end,
            set = function(_, v) C.SetCollapsed(v); if Notify then Notify() end end },

        fadeHdr = hdr("Fade when idle", 10, "After a while with no mouse over the chat, nothing typed, and no new message, the chat fades to the opacity below (0 = fully hidden). The mouse over it, typing, or a new message brings it back."),
        fade = tog("Fade the chat when it is idle", "fadeOn", 11),
        after = rng("Seconds before it fades", "fadeAfter", 12, 2, 120),
        to = rng("Opacity when faded (%)", "fadeTo", 13, 0, 100, "0 hides it completely.", 5),
        secs = rng("Fade duration (seconds)", "fadeSeconds", 14, 0.1, 3, nil, 0.1),
        wake = tog("A new message brings the chat back", "fadeWake", 15),
        bar = tog("Fade the Chat Data Panel too", "fadeBar", 16),

        textHdr = hdr("Old lines", 20),
        textFade = tog("Fade old lines away", "textFade", 21, "The game's own per-line fade. Off keeps every line visible until it scrolls out."),
        textAfter = rng("Seconds a line stays visible", "textFadeAfter", 22, 10, 600, nil, 10, function() return not S().textFade end),
    } }

    -- 5. FILTERS AND LINKS --------------------------------------------------------------------------------------------------
    local filters = { type = "group", name = "Filters", order = 5, args = {
        n = note("These work on public messages (say, yell, emotes, channels) and whispers. Your own messages are never filtered. Protected (secret) lines are never touched. With repeats, phrases and links all off, nothing here looks at a message; the game keeps the (idle) filter until you /reload.", 1),
        repHdr = hdr("Repeated messages", 10),
        rep = tog("Hide repeated messages", "spamRepeat", 11, "Hides the same message from the same player when it comes again within the time below. Whispers are not checked."),
        repSec = rng("Repeat window (seconds)", "spamSeconds", 12, 5, 300, nil, 5, function() return not S().spamRepeat end),
        phrasesHdr = hdr("Blocked phrases", 20),
        phrases = { type = "input", name = "Your blocked-phrase list (one per line)", order = 21, width = "full", multiline = 6,
            desc = "A message containing any of these (ignoring capital letters) is hidden.",
            get = function() return S().spamPhrases or "" end,
            set = function(_, v) local s = ns.chat2; if s then s.spamPhrases = v or "" end; Re() end },
        word = tog("Match whole words only", "spamWord", 22, "'gold' would then not match 'golden'."),
        stats = { type = "description", order = 23, width = "full", name = function() return "Hidden this session: " .. tostring(C.stats.suppressed) end },
        clickHdr = hdr("Quick ignore", 30),
        click = tog("Ctrl + right-click a player's name in chat to ignore them", "ignoreClick", 31),
        linkHdr = hdr("Links", 40),
        links = tog("Make web addresses clickable", "links", 41, "Click one to open a box with the address selected; press Ctrl+C to copy it."),
        linkCol = col3("Link color", "link", 42),
    } }

    -- 6. HISTORY ------------------------------------------------------------------------------------------------------------
    local history = { type = "group", name = "History", order = 6, args = {
        n = note("The history window lists recent messages as plain text you can select and copy, with a button per chat tab and a search box. It is kept in memory only: nothing is written to disk, and it is gone when you log out or reload. Combat log lines are not recorded.", 1),
        keepHdr = hdr("Keeping messages", 10),
        on = tog("Keep recent messages for the history window", "histOn", 11),
        size = rng("Messages kept", "histSize", 12, 20, 2000, nil, 10, function() return not S().histOn end),
        whispers = sel("Whisper tabs", "histWhispers", 12.5, { game = "As the game's New Whispers setting", one = "All whispers in one tab" },
            { "game", "one" }, "Which whisper tabs the history window has. As the game: with Options > Social > New Whispers set to New Tab or Both, one tab per conversation; set to In-line, none (whispers stay in the chat tabs that show them). All whispers in one tab: a Whispers tab with every whisper, sent and received.",
            function() return not S().histOn end),
        console = tog("Keep console lines in a Console tab", "histConsole", 13,
            "Lines printed by XayaUI (/xui output) and other addons, and the game's system messages, are kept in their own Console tab of the history window instead of mixing with chat. Lines an addon writes straight into a chat window without printing them are not seen. Turned off, its hook on printed lines stays until you /reload but does nothing.",
            function() return not S().histOn end),
        openHdr = hdr("Window", 20),
        histBtn = tog("Show the small history button at the end of the tab row", "histButton", 21, nil, nil, "hist"),
        open = { type = "execute", name = "Open the history window", order = 22, func = function() C.History_Toggle() end },
    } }

    -- 7. SOUNDS -------------------------------------------------------------------------------------------------------------
    local sounds = { type = "group", name = "Sounds", order = 7, args = {
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

    -- Whisper sound overrides (Sounds.lua C.WhisperOverride): a sound for Battle.net favorites, and one per listed sender
    do
        local function WS()
            local s = ns.chat2; if not s then return nil end
            s.whisperSounds = s.whisperSounds or {}; s.whisperSounds.list = s.whisperSounds.list or {}
            return s.whisperSounds
        end
        local function SoundArgs(getCfg, base)
            return {
                snd = { type = "select", name = "Sound", order = base + 1, width = "double",
                    values = function() local v = SoundChoices(); return v end, sorting = function() local _, o = SoundChoices(); return o end,
                    get = function() local c = getCfg(); return (c and c.value and c.value ~= "") and (tostring(c.source) .. "|" .. tostring(c.value)) or "" end,
                    set = function(_, k)
                        local c = getCfg(true); if not c then return end
                        if k == "" then c.value = "" else c.source, c.value = k:match("^(%w+)|(.*)$") end
                    end },
                chan = { type = "select", name = "Sound channel", order = base + 2,
                    values = { Master = "Master", SFX = "Sound effects", Music = "Music", Ambience = "Ambience", Dialog = "Dialog" }, sorting = { "Master", "SFX", "Music", "Ambience", "Dialog" },
                    get = function() local c = getCfg(); return c and c.channel or "Master" end,
                    set = function(_, v) local c = getCfg(true); if c then c.channel = v end end },
                test = { type = "execute", name = "Test", order = base + 3, width = "half",
                    func = function() local c = getCfg(); if c and c.value and c.value ~= "" and ns.PlaySoundPreview then ns.PlaySoundPreview(c) end end },
            }
        end
        local function wOff() return ns.chat2 and ns.chat2.whisperSoundsOn == false end
        local W = {}   -- one titled box (a header line would split the Sounds page into tabs)
        sounds.args.whisper = { type = "group", inline = true, order = 40, name = "Whisper sound overrides", args = W }
        W.wNote = note("A whisper from someone on this list, or from one of your Battle.net favorites, plays its own sound instead of the tab sounds. Type a character name (Name or Name-Realm) or a BattleTag (Name#1234, or only the part before #). While the game hides who sent a message (chat lockdown), the tab sounds play as usual. Friend groups made by other addons cannot be read: the game itself has no friend groups, only favorites.", 41)
        W.wOn = tog("Use whisper sound overrides", "whisperSoundsOn", 42)
        local function favCfg(create)
            local ws = WS(); if not ws then return nil end
            if create and not ws.fav then ws.fav = { enabled = false, source = "kit", value = "", channel = "Master" } end
            return ws.fav
        end
        local favArgs = SoundArgs(favCfg, 1)
        favArgs.en = { type = "toggle", name = "Play a sound for Battle.net favorites", order = 1, width = "double",
            get = function() local c = favCfg(); return c and c.enabled and true or false end,
            set = function(_, v) favCfg(true).enabled = v and true or false end }
        W.wFav = { type = "group", inline = true, order = 43, name = "Battle.net favorites", hidden = wOff, args = favArgs }
        local MAXW = 20
        for i = 1, MAXW do
            local function eCfg() local ws = WS(); return ws and ws.list[i] end
            local a = SoundArgs(eCfg, 1)
            a.who = { type = "input", name = "Character or BattleTag", order = 1, width = "double",
                get = function() local c = eCfg(); return c and c.who or "" end,
                set = function(_, v) local c = eCfg(); if c then c.who = tostring(v or ""):sub(1, 64) end; Notify() end }
            a.remove = { type = "execute", name = "Remove", order = 9, width = "half",
                func = function() local ws = WS(); if ws and ws.list[i] then table.remove(ws.list, i) end; Notify() end }
            W["w" .. i] = { type = "group", inline = true, order = 44 + i / 100,
                name = function() local c = eCfg(); local w = c and c.who or ""; return "Override " .. i .. ((w ~= "") and (": " .. w) or "") end,
                hidden = function() local ws = WS(); return wOff() or not (ws and ws.list[i]) end, args = a }
        end
        W.wAdd = { type = "execute", name = "+ Add a sender", order = 46, hidden = wOff,
            disabled = function() local ws = WS(); return ws and #ws.list >= MAXW end,
            func = function() local ws = WS(); if ws and #ws.list < MAXW then ws.list[#ws.list + 1] = { who = "", enabled = true, source = "kit", value = "", channel = "Master" } end; Notify() end }
    end

    local privacy = ns.ChatPrivacy_Options and ns.ChatPrivacy_Options(Notify) or nil
    if privacy then privacy.order = 8; privacy.name = "Privacy" end

    -- The Chat Panel node: its own page holds the panel-wide switches (moved from the top of Layout); the parts are nodes under it,
    -- and each part's header sections become tabs.
    -- "Enable Chat Panel" is the tick box on this page's row in the left pane (xuiSwitch; Chat 0.6.18, S1 #48: "individual toggles
    -- for individual reskins"), greyed while the Blizzard UI Reskin tab's own switch is off
    local switch = layout.args.enabled
    switch.order, switch.width = nil, nil
    switch.disabled = function() return not ns.ReskinTabOn() end
    switch.desc = switch.desc .. " Greyed while Blizzard UI Reskin is off (this tab's Overview)."
    local overview = { blocked = layout.args.blocked, intro = layout.args.intro, theme = layout.args.theme }
    layout.args.blocked, layout.args.intro, layout.args.enabled, layout.args.theme = nil, nil, nil, nil
    local parts = { layout = layout, look = look, bar = bar, behavior = behavior, filters = filters, history = history, sounds = sounds, privacy = privacy }
    for key, part in pairs(parts) do
        if ns.SectionTabs then ns.SectionTabs(part) end
        overview[key] = part
    end
    -- Privacy's tabs in the order Xaya named them: Look, Button, then Area and behavior
    if privacy and privacy.args and privacy.args.tab_btnHdr then privacy.args.tab_btnHdr.order = 20 end
    return { type = "group", name = "Chat Panel", order = 1, childGroups = "tree", xuiSwitch = switch, args = overview }
end

-------------------------------------------------------------------------------
-- Plugs into core through Modules.lua (0.5.108): core never calls this file by name.
-------------------------------------------------------------------------------
-- module "reskin": the page is drawn in the Blizzard UI Reskin tab (Chat 0.6.13; Xaya 2026-11-05: "Take all reskins and put them into a
-- new tab: Blizzard UI Reskin"; the Chat Panel restyles Blizzard's chat)
ns.RegisterSettingsPage("reskin", "chatpanel", ns.BuildChatTab)
ns.RegisterLauncher({ "chat", "Chat Panel", "Open the Chat Panel settings (also /xui chat settings)", function() C.OpenSettings() end, order = 40 })
