-------------------------------------------------------------------------------
-- Options.lua (XayaUI Chat) : the Chat Panel settings (Chat > Chat Panel). The Chat Panel node holds the panel-wide switches; its parts
-- are nodes under it in the left pane (General, Chat Tabs, Layout, Chat Data Panel, Filters, Sounds, Privacy; Chat 0.6.31), and each
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
-- (Chat 0.6.31; REQUEST-LOG A14 CHATREV-11) parts that moved into General keep their old names as addresses
local MOVED = { look = "general", behavior = "general", history = "general" }
-- (Chat 0.6.33; UI-18 / UI-19 / UI-21) parts on QoL > Improved Chat (old names too); "improved" opens that page itself
local IMPROVED = { improved = "", behavior = "general", history = "general", fade = "general", bar = "bar", filters = "filters",
    sounds = "sounds", privacy = "privacy", sidebar = "sidebar" }
function C.OpenSettings(part, section)
    local ip = part and IMPROVED[part]
    if ip then
        if ip == "" then ns.OpenSettingsPage("qol", "improvedchat")
        elseif section then ns.OpenSettingsPage("qol", "improvedchat", ip, section)
        else ns.OpenSettingsPage("qol", "improvedchat", ip) end
        return
    end
    part = MOVED[part] or part
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

local function Build(Notify, which)
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
        enabled = { type = "toggle", name = "Enable Chat Panel", order = 3, width = "full", tip = "Restyles Blizzard's chat into one clean block; untick to get Blizzard's chat back.",
            desc = "Uncheck to restore Blizzard's default chat. /reload after unchecking to clear it fully.",
            get = function() return S().enabled and true or false end,
            set = function(_, v) local s = ns.chat2; if s then s.enabled = v and true or false end; Re() end },
        theme = tog("Use the XayaUI theme for the chat's colors and font", "useTheme", 4,
            "Colors the chat and sets its font from your XayaUI theme. Appearance colors are then ignored; opacity sliders still apply."),

        posHdr = hdr("Position and size", 10),
        w = rng("Width (pixels)", "width", 11, 220, 1000, "Sets the chat pane's width (the whole block, with a Chat Data Panel above or below)."),
        h = rng("Height of the chat pane (pixels)", "height", 12, 90, 800, "Sets the height of the tabs, text and input line together. A Chat Data Panel above or below adds to it."),
        move = { type = "execute", name = "Move or resize the chat", order = 13, desc = "Shows a box to drag the chat, or drag its top-right corner to resize. Click again (or /xui chat move) to finish.",
            func = function() C.ToggleMover() end },
        reset = { type = "execute", name = "Reset position and size", order = 14, func = function() C.Command("reset"); if Notify then Notify() end end },

        insideHdr = hdr("Inside the pane", 20),
        tabs = tog("Show the tab row", "tabsShow", 21, "Hiding the tabs also hides the way to switch chat windows."),
        tabH = rng("Tab height (pixels)", "tabHeight", 22, 16, 40, nil, 1, nil, "tabs"),
        inH = rng("Input line height (pixels)", "inputH", 23, 18, 60, nil, 1, nil, "input"),
        -- (Chat 0.6.34; REQUEST-LOG UI-15 / UI-17 / A16 CR-7) top (under or above the tab row), bottom, or free move (place and width in
        -- the mover only: "configurable in mover gui, not from console line")
        inPos = sel("Input line", "inputPos", 23.5, { BOTTOM = "Bottom", TOP = "Top, under the tabs", ABOVE = "Top, above the tabs", FREE = "Free move" },
            { "BOTTOM", "TOP", "ABOVE", "FREE" }, "Where the line you type in sits. Free move: drag it and set its width in the mover (Move or resize the chat).", nil, "input"),
        inset = rng("Text inset from the edge (pixels)", "textInset", 24, 2, 30, nil, 1, nil, "text"),
        wrapIndent = tog("Indent wrapped lines", "wrapIndent", 25,
            "Indents the wrapped lines of a long message, so you can see where each message begins.", nil, "text"),
        ownScroll = tog("Chat Panel scroll bar (slow scrolling)", "scrollOwn", 26,
            "Shows a slim scroll bar right of the text; each arrow click moves one line. Hold an arrow to scroll at the speed below.", nil, "ownscroll"),
        scrollSpeed = rng("Scroll bar: lines per second while an arrow is held", "scrollSpeed", 27, 1, 30, nil, 1, function() return not S().scrollOwn end, "ownscroll"),
        scrollW = rng("Scroll bar width (pixels)", "scrollW", 28, 6, 20, nil, 1, function() return not S().scrollOwn end, "ownscroll"),

        piecesHdr = hdr("Blizzard's own pieces", 30, "The button strip (menu, channels, voice), the round social button, the scroll bar, and the back-to-newest arrow."),
        strip = sel("Blizzard button strip", "stripMode", 31, { HIDE = "Hidden", LEFT = "Left of chat", RIGHT = "Right of chat" }, { "HIDE", "LEFT", "RIGHT" },
            "Places the chat menu, channels and voice buttons beside the chat, or hides them.", nil, "strip"),
        social = sel("Social button", "socialMode", 32, { HIDE = "Hidden", SHOW = "Above the chat" }, { "HIDE", "SHOW" },
            "Shows or hides the round social button near the chat.", nil, "social"),
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
        on = tog("Show the Chat Data Panel", "barOn", 1, "Shows data blocks attached to the chat, above, below or beside it. It collapses with the chat."),
        barHdr = hdr("Position", 5),
        side = sel("Place the panel", "barSide", 6, { TOP = "Above the chat", BOTTOM = "Below the chat", LEFT = "Left of the chat", RIGHT = "Right of the chat" }, { "BOTTOM", "TOP", "LEFT", "RIGHT" }, nil, nil, "bar"),
        sizing = sel("Block widths", "barSizing", 7, { EVEN = "Equal", AUTO = "Follow the text" }, { "EVEN", "AUTO" },
            "Makes every block the same width, or each as wide as its text. With Follow the text, blocks marked Fill take the space left."),
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
            desc = "Hides the chat, leaving only the panel or a small arrow. Same as the arrow on the Chat Data Panel.",
            get = function() return S().collapsed and true or false end,
            set = function(_, v) C.SetCollapsed(v); if Notify then Notify() end end },

        fadeHdr = hdr("Fade when idle", 10, "Fades the chat to the opacity below when idle. The mouse over it, typing or a new message brings it back."),
        fade = tog("Fade the chat when it is idle", "fadeOn", 11),
        after = rng("Seconds before it fades", "fadeAfter", 12, 2, 120),
        to = rng("Opacity when faded (%)", "fadeTo", 13, 0, 100, "0 hides it completely.", 5),
        secs = rng("Fade duration (seconds)", "fadeSeconds", 14, 0.1, 3, nil, 0.1),
        wake = tog("A new message brings the chat back", "fadeWake", 15),
        hoverWake = (function() local o = tog("The mouse over the chat brings it back", "fadeHover", 15.5); o.get = function() return S().fadeHover ~= false end; return o end)(),
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
        click = tog("Click a player's name in chat to ignore them", "ignoreClick", 31, "With the click chosen below (Ctrl + right-click unless you change it)."),
        -- (Chat 0.6.25; UI-12 / UI-17) the click: a right-click with modifiers the game has no key binding for, or one you record
        clickCombo = { type = "select", name = "Click", order = 32, width = "normal",
            desc = "Sets the right-click combination, from those the game has no key binding for. Record your own with the button beside it.",
            hidden = function() return not S().ignoreClick end,
            values = function()
                local v = {}
                for _, c in ipairs(C.FreeCombos and C.FreeCombos() or {}) do v[c] = C.ComboName(c) end
                local cur = C.IgnoreCombo and C.IgnoreCombo()
                if cur and not v[cur] then v[cur] = C.ComboName(cur) .. ((C.ComboBinding(cur) and " (also a key binding)") or " (recorded)") end
                return v
            end,
            get = function() return C.IgnoreCombo and C.IgnoreCombo() end,
            set = function(_, v) local s2 = ns.chat2; if s2 then s2.ignoreCombo = v end; Re() end },
        clickRec = { type = "execute", name = "Record your own", order = 33, width = "normal",
            desc = "Opens a box: hold Alt, Ctrl, Shift or Cmd and click it with the mouse button you want.",
            hidden = function() return not S().ignoreClick end,
            func = function() if C.RecordCombo then C.RecordCombo(function() Re() end) end end },
        clickNow = { type = "description", order = 34, width = "full", hidden = function() return not S().ignoreClick end,
            name = function()
                local cur = C.IgnoreCombo and C.IgnoreCombo() or "CTRL-BUTTON2"
                local act = C.ComboBinding and C.ComboBinding(cur)
                return "Now: " .. C.ComboName(cur) .. " on a player's name." .. (act and ("  |cffff8a3dThe game also has a key binding on it (" .. act .. ").|r") or "")
            end },
        linkHdr = hdr("Links", 40),
        links = tog("Make web addresses clickable", "links", 41, "Click one to open a box with the address selected; press Ctrl+C to copy it."),
        linkCol = col3("Link color", "link", 42),
    } }

    -- 6. HISTORY ------------------------------------------------------------------------------------------------------------
    -- (Chat 0.6.26; UI-13 / UI-16 / UI-17 / UI-30 / UI-31) in-game and Battle.net whispers each: as the game (default), one tab per
    -- conversation, one consolidated tab, or both; a box combines the consolidated tabs into one "Whispers" tab
    local WV = { game = "As the game's New Whispers setting", each = "Individual tabs", one = "Consolidated tab", both = "Both" }
    local function WhisperSel(name, field, order, desc)
        return { type = "select", name = name, desc = desc, order = order, values = WV, sorting = { "game", "each", "one", "both" },
            hidden = function() return not S().histOn end,
            get = function() local s2 = S(); local v = s2[field]; if v == nil and s2.histWhispers == "one" then return "one" end; return v or "game" end,
            set = function(_, v)
                local s2 = ns.chat2
                if s2 then
                    if s2.histWhispers == "one" then   -- the 0.6.15 setting: becomes the two lists (both consolidated) and combined
                        s2.histWhispers = "game"
                        s2.histWhispersW = s2.histWhispersW or "one"; s2.histWhispersB = s2.histWhispersB or "one"
                        if s2.histWhispersCombine == nil then s2.histWhispersCombine = true end
                    end
                    s2[field] = (v ~= "game") and v or nil
                end
                Re()
            end }
    end
    local history = { type = "group", name = "History", order = 6, args = {
        n = note("The history window lists recent messages as plain text you can select and copy, with a button per chat tab and a search box. It is kept in memory only: nothing is written to disk, and it is gone when you log out or reload. Combat log lines are not recorded.", 1),
        keepHdr = hdr("Keeping messages", 10),
        on = tog("Keep recent messages for the history window", "histOn", 11),
        size = rng("Messages kept", "histSize", 12, 20, 2000, nil, 10, function() return not S().histOn end),
        -- (Chat 0.6.26; UI-13 / UI-16 / UI-17 / UI-30 / UI-31) in-game and Battle.net whispers each: as the game (default), one tab per
        -- conversation, one consolidated tab, or both; a box combines the consolidated tabs into one "Whispers" tab
        whispersW = WhisperSel("In-game whisper tabs", "histWhispersW", 12.5, "Sets in-game whisper tabs: one per conversation, one In-Game Whispers tab, or both. As the game follows Options > Social > New Whispers."),
        whispersB = WhisperSel("Battle.net whisper tabs", "histWhispersB", 12.6, "Sets Battle.net whisper tabs: one per friend, one BNet Whispers tab, or both. As the game follows Options > Social > New Whispers."),
        whispersCombine = { type = "toggle", name = "Combine Battle.net and in-game whispers in the consolidated tab", order = 12.7, width = "full",
            desc = "Uses one Whispers tab instead of In-Game Whispers and BNet Whispers. Needs Consolidated tab or Both above.",
            hidden = function() return not S().histOn end,
            disabled = function()
                local w, b = C.History_WhisperModes()
                return not (w == "one" or w == "both" or b == "one" or b == "both")
            end,
            get = function() local _, _, c = C.History_WhisperModes(); return c end,
            set = function(_, v) local s2 = ns.chat2; if s2 then s2.histWhispersCombine = v and true or false end; Re() end },
        console = tog("Keep console lines in a Console tab", "histConsole", 13,
            "Keeps lines printed by XayaUI, other addons and the game's system messages in their own Console tab of the history window.",
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

    ---------------------------------------------------------------------------------------------------------------------------
    -- (Chat 0.6.31; REQUEST-LOG A14 CHATREV-11, Xaya 2026-11-07: "why is chat functionality still not placed correctly in its appropriate
    -- location?" / "read what I said in the note"; her #246 words, built as given:) "general tab should have font options, color +
    -- display options, scroll and fade options"; "Chat Tabs should be its own pane"; "Chat history likely belongs in the general tab
    -- options"; "Timestamp, copying, and links options also likely belong in general options". The controls are MOVED from the parts
    -- above (each exists once; settings keys unchanged). Appearance, Fade and hide and History are emptied into General and removed.
    ---------------------------------------------------------------------------------------------------------------------------
    local function mv(src, key, dst, order, newKey)
        local o = src.args[key]
        if not o then return end
        src.args[key] = nil
        o.order = order
        dst.args[newKey or key] = o
    end
    -- the game's own Chat Timestamps setting (CVar showTimestamps; the same list as Options > Social > Chat Timestamps,
    -- Blizzard_SettingsDefinitions_Frame/Social.lua, wow-ui-source live): none, or one of the game's TIMESTAMP_FORMAT_* strings
    local TS_KEYS = { "TIMESTAMP_FORMAT_HHMM", "TIMESTAMP_FORMAT_HHMMSS", "TIMESTAMP_FORMAT_HHMM_AMPM", "TIMESTAMP_FORMAT_HHMMSS_AMPM",
        "TIMESTAMP_FORMAT_HHMM_24HR", "TIMESTAMP_FORMAT_HHMMSS_24HR" }
    local function TsLabel(fmt)
        local ok, v = pcall(function()
            return TimeUtil.BetterDate(fmt, time({ year = 2010, month = 12, day = 15, hour = 15, min = 27, sec = 32 }))
        end)
        return (ok and type(v) == "string" and v ~= "") and v or tostring(fmt)
    end
    local function TsGet()
        local cv = rawget(_G, "C_CVar")
        local ok, v = pcall(function() return cv.GetCVar("showTimestamps") end)
        return (ok and type(v) == "string" and not (C.IsSecret and C.IsSecret(v))) and v or "none"
    end
    local function TsList()
        local values, order = { none = rawget(_G, "TIMESTAMP_FORMAT_NONE") or "None" }, { "none" }
        for _, k in ipairs(TS_KEYS) do
            local fmt = rawget(_G, k)
            if type(fmt) == "string" and not values[fmt] then values[fmt] = TsLabel(fmt); order[#order + 1] = fmt end
        end
        local cur = TsGet()
        if not values[cur] then values[cur] = TsLabel(cur); order[#order + 1] = cur end
        return values, order
    end
    local timestamps = { type = "select", name = "Timestamps", order = 81,
        desc = "The time in front of each new chat line. This is the game's own Chat Timestamps setting (Options > Social): changing it here changes it there too.",
        values = function() local v = TsList(); return v end, sorting = function() local _, o = TsList(); return o end,
        get = TsGet,
        set = function(_, v) local cv = rawget(_G, "C_CVar"); pcall(function() cv.SetCVar("showTimestamps", tostring(v)) end); if Notify then Notify() end end }

    ---------------------------------------------------------------------------------------------------------------------------
    -- (Chat 0.6.33; REQUEST-LOG UI-18 / UI-19 / UI-21, Xaya 2026-11-06) the two pages. Her rule: "purely visual elements remain in skin
    -- and all things that directly modify chat behavior go into QoL"; her item list, "Yes, as listed":
    --   SKIN (Blizzard UI Reskin > Chat Panel): Appearance (colours, fonts, boxes, textures, tab look, input look), the chat block's size,
    --   position and mover, input line top / bottom / free move, indent wrapped lines, which of Blizzard's pieces show (button strip,
    --   scroll bar, social button).
    --   QoL > IMPROVED CHAT: Filters (ignore click + modifier), History (whisper tabs), Sounds, Privacy cover, Fade and hide (+ hover
    --   wake), the Chat Data Panel, the sidebar, the slow-scrolling scroll bar.
    -- Two independent switches (her answer "1"), and Improved Chat carries her note (below). Her #246 General headers (Chat 0.6.31,
    -- CHATREV-11) are kept, each on the page its items now belong to. Every control exists once; settings keys are unchanged.
    ---------------------------------------------------------------------------------------------------------------------------
    local function mv(src, key, dst, order, newKey)
        local o = src.args[key]
        if not o then return end
        src.args[key] = nil
        o.order = order
        dst.args[newKey or key] = o
    end
    -- the game's own Chat Timestamps setting (CVar showTimestamps; the same list as Options > Social > Chat Timestamps,
    -- Blizzard_SettingsDefinitions_Frame/Social.lua, wow-ui-source live): none, or one of the game's TIMESTAMP_FORMAT_* strings
    local TS_KEYS = { "TIMESTAMP_FORMAT_HHMM", "TIMESTAMP_FORMAT_HHMMSS", "TIMESTAMP_FORMAT_HHMM_AMPM", "TIMESTAMP_FORMAT_HHMMSS_AMPM",
        "TIMESTAMP_FORMAT_HHMM_24HR", "TIMESTAMP_FORMAT_HHMMSS_24HR" }
    local function TsLabel(fmt)
        local ok, v = pcall(function()
            return TimeUtil.BetterDate(fmt, time({ year = 2010, month = 12, day = 15, hour = 15, min = 27, sec = 32 }))
        end)
        return (ok and type(v) == "string" and v ~= "") and v or tostring(fmt)
    end
    local function TsGet()
        local cv = rawget(_G, "C_CVar")
        local ok, v = pcall(function() return cv.GetCVar("showTimestamps") end)
        return (ok and type(v) == "string" and not (C.IsSecret and C.IsSecret(v))) and v or "none"
    end
    local function TsList()
        local values, order = { none = rawget(_G, "TIMESTAMP_FORMAT_NONE") or "None" }, { "none" }
        for _, k in ipairs(TS_KEYS) do
            local fmt = rawget(_G, k)
            if type(fmt) == "string" and not values[fmt] then values[fmt] = TsLabel(fmt); order[#order + 1] = fmt end
        end
        local cur = TsGet()
        if not values[cur] then values[cur] = TsLabel(cur); order[#order + 1] = cur end
        return values, order
    end
    local timestamps = { type = "select", name = "Timestamps", order = 81,
        desc = "The time in front of each new chat line. This is the game's own Chat Timestamps setting (Options > Social): changing it here changes it there too.",
        values = function() local v = TsList(); return v end, sorting = function() local _, o = TsList(); return o end,
        get = TsGet,
        set = function(_, v) local cv = rawget(_G, "C_CVar"); pcall(function() cv.SetCVar("showTimestamps", tostring(v)) end); if Notify then Notify() end end }

    -- SKIN: General ("general tab should have font options, color + display options")
    local general = { type = "group", name = "General", order = 1, args = {
        fontHdr = hdr("Font options", 10),
        colorHdr = hdr("Color + display options", 20),
    } }
    mv(look, "font", general, 11); mv(look, "outline", general, 12); mv(look, "fontSize", general, 13)
    mv(look, "themeNote", general, 21)
    local o = 22
    for _, k in ipairs({ "bg", "bgCol", "bd", "bdCol", "tex", "texA", "tile", "inBg", "inBd", "inFocus", "hint", "hintText" }) do mv(look, k, general, o); o = o + 1 end

    -- SKIN: Chat Tabs ("Chat Tabs should be its own pane"): the tab row and the tabs' look
    local chatTabs = { type = "group", name = "Chat Tabs", order = 2, args = { rowHdr = hdr("Tab row", 10) } }
    mv(layout, "tabs", chatTabs, 11); mv(layout, "tabH", chatTabs, 12)
    o = 13
    for _, k in ipairs({ "tabFont", "tabOutline", "tabSize", "tabText", "tabSel", "tabBgOn", "tabBg", "tabSelBg" }) do mv(look, k, chatTabs, o); o = o + 1 end

    -- SKIN: Layout keeps place, size and mover, the inside of the pane and Blizzard's own pieces (button strip, scroll bar, social button,
    -- back-to-newest arrow). The slow-scrolling bar is Improved Chat's: Blizzard's scroll bar shows here while that one is off.
    if layout.args.scroll then
        layout.args.scroll.order = 33.5
        layout.args.scroll.desc = "Used only while Improved Chat's slow-scrolling scroll bar is off (QoL > Improved Chat > General)."
        layout.args.scroll.hidden = function() return C.OwnScroll and C.OwnScroll() end
    end

    -- IMPROVED CHAT: General (her #246 headers that hold behaviour: "scroll and fade options", "Chat history", "Timestamp, copying,
    -- and links")
    local igeneral = { type = "group", name = "General", order = 1, args = {
        scrollHdr = hdr("Scroll and fade options", 40),
        histHdr = hdr("Chat history", 60),
        tsHdr = hdr("Timestamp, copying, and links", 80),
        timestamps = timestamps,
    } }
    mv(layout, "ownScroll", igeneral, 41); mv(layout, "scrollSpeed", igeneral, 42); mv(layout, "scrollW", igeneral, 43)
    o = 46
    for _, k in ipairs({ "fade", "after", "to", "secs", "wake", "hoverWake" }) do mv(behavior, k, igeneral, o); o = o + 1 end
    mv(behavior, "bar", igeneral, 52, "fadeBar"); mv(behavior, "textFade", igeneral, 53); mv(behavior, "textAfter", igeneral, 54)
    mv(behavior, "collapse", igeneral, 55)
    mv(filters, "links", igeneral, 82); mv(filters, "linkCol", igeneral, 83)
    mv(history, "histBtn", igeneral, 84); mv(history, "open", igeneral, 85, "histOpen")
    -- everything else on the History page, in its own order (its whisper lists, the console tab, ...): Chat history
    local rest = {}
    for k, v in pairs(history.args) do if v.type ~= "header" then rest[#rest + 1] = k end end
    table.sort(rest, function(a, b) return (tonumber(history.args[a].order) or 0) < (tonumber(history.args[b].order) or 0) end)
    o = 61
    for _, k in ipairs(rest) do mv(history, k, igeneral, o, igeneral.args[k] and ("hist_" .. k) or k); o = o + 0.5 end
    if igeneral.args.histOpen then igeneral.args.histOpen.desc = "The history window lists recent messages as plain text you can select and copy (Ctrl+C)." end
    -- (Chat 0.6.31; REQUEST-LOG A14 CHATREV-10, Xaya 2026-11-07: "creating new whisper tabs by sending a new message don't
    -- automatically shift to a new whisper window from general tab"; her setting "Both"; her answer "Yes, as an option") Whispers.lua;
    -- with the whisper tab lists, under Chat history (UI-21: "History (whisper tabs)")
    igeneral.args.whisperSelect = tog("Switch to a new whisper tab I start", "whisperSelect", 75,
        "When you whisper someone and the game opens a new tab for them, the chat switches to it. Needed only with the game's New Whispers set to Both (New Tab does it itself; In-line makes no tabs).")
    filters.args.linkHdr = nil
    mv(layout, "secretNote", filters, 91); mv(layout, "noteHdr", filters, 90)
    layout.args.toBottom.order = 34

    layout.order, bar.order, filters.order, sounds.order = 3, 2, 3, 4
    local privacy = ns.ChatPrivacy_Options and ns.ChatPrivacy_Options(Notify) or nil
    if privacy then privacy.order = 5; privacy.name = "Privacy" end
    local sidebar = C.Sidebar_Options and C.Sidebar_Options(Notify, S, Re) or nil
    if sidebar then sidebar.order = 6 end

    if which == "improved" then
        local introText = "Improved Chat adds to how chat behaves: the slow-scrolling scroll bar, fading and hiding the chat, the history window and whisper tabs, timestamps and links, filters, sounds, the privacy cover, the Chat Data Panel and the sidebar. Its switch is separate from Blizzard Reskin > Chat Panel, which only changes how chat looks."
        local overview = {
            intro = note(introText, 1),
            -- her words (UI-19): "note in improved chat that it likely displays better with a chat reskin (should support other chat reskin options)"
            reskinNote = note("|cffaaaaaaImproved Chat likely displays better with a chat reskin, such as Blizzard Reskin > Chat Panel. It also works with other chat reskins: with the Chat Panel off it places its pieces around the chat where it is.|r", 2),
        }
        local iparts = { general = igeneral, bar = bar, filters = filters, sounds = sounds, privacy = privacy, sidebar = sidebar }
        for key, part in pairs(iparts) do
            if ns.SectionTabs then ns.SectionTabs(part) end
            overview[key] = part
        end
        -- Privacy's tabs in the order Xaya named them: Look, Button, then Area and behavior
        if privacy and privacy.args and privacy.args.tab_btnHdr then privacy.args.tab_btnHdr.order = 20 end
        local switch = { type = "toggle", name = "Improved Chat",
            tip = "Adds chat features: history, filters, sounds, fading, the privacy cover and the Chat Data Panel.",
            desc = "Takes effect after a reload; off, none of Improved Chat's parts run and nothing of them is made. Separate from the Chat Panel's switch.",
            get = function() return S().improvedOn ~= false end,
            -- (Chat 0.6.43; PS-57, #480) saves and asks for a reload; before, C.Refresh ran at once (Re)
            set = function(_, v)
                local s = ns.chat2; if not s then return end
                ns.SwitchSaveForReload("chat.improved", s.improvedOn ~= false, function() s.improvedOn = v and true or false end, "Improved Chat")
                if Notify then Notify() end
            end }
        return { type = "group", name = "Improved Chat", order = 3, childGroups = "tree", xuiSwitch = switch, args = overview }
    end

    if layout.args.intro then
        layout.args.intro.name = "Chat Panel restyles Blizzard's own chat window in place and puts it in one block: the tabs, the text, and the line you type in are inside the pane. It only changes how chat looks; what the addon adds to how chat behaves is in QoL > Improved Chat. /xui chat shows what ran and what failed."
    end
    -- The Chat Panel node: its own page holds the panel-wide switches (moved from the top of Layout); the parts are nodes under it,
    -- and each part's header sections become tabs.
    -- "Enable Chat Panel" is the tick box on this page's row in the left pane (xuiSwitch; Chat 0.6.18, S1 #48: "individual toggles
    -- for individual reskins"), greyed while the Blizzard UI Reskin tab's own switch is off
    local switch = layout.args.enabled
    switch.order, switch.width = nil, nil
    switch.disabled = function() return not ns.ReskinTabOn() end
    switch.desc = "Takes effect after a reload; off gives Blizzard's chat back as the game draws it (QoL > Improved Chat has its own switch). Greyed while Blizzard Reskin is off (this tab's Overview)."
    -- (Chat 0.6.43; PS-57, #480) saves and asks for a reload; before, C.Refresh ran at once (Re)
    switch.set = function(_, v)
        local s = ns.chat2; if not s then return end
        ns.SwitchSaveForReload("chat.panel", s.enabled, function() s.enabled = v and true or false end, "Chat Panel")
        if Notify then Notify() end
    end
    local overview = { blocked = layout.args.blocked, intro = layout.args.intro, theme = layout.args.theme }
    layout.args.blocked, layout.args.intro, layout.args.enabled, layout.args.theme = nil, nil, nil, nil
    layout.order = 3
    local parts = { general = general, tabs = chatTabs, layout = layout }
    for key, part in pairs(parts) do
        if ns.SectionTabs then ns.SectionTabs(part) end
        overview[key] = part
    end
    return { type = "group", name = "Chat Panel", order = 1, childGroups = "tree", xuiSwitch = switch, args = overview }
end
function ns.BuildChatTab(Notify) return Build(Notify, "skin") end
-- (Chat 0.6.33; UI-18 / UI-19 / UI-21) QoL > Improved Chat
function ns.BuildImprovedChatTab(Notify) return Build(Notify, "improved") end

-------------------------------------------------------------------------------
-- Plugs into core through Modules.lua (0.5.108): core never calls this file by name.
-------------------------------------------------------------------------------
-- module "reskin": the page is drawn in the Blizzard UI Reskin tab (Chat 0.6.13; Xaya 2026-11-05: "Take all reskins and put them into a
-- new tab: Blizzard UI Reskin"; the Chat Panel restyles Blizzard's chat)
ns.RegisterSettingsPage("reskin", "chatpanel", ns.BuildChatTab)
ns.RegisterSettingsPage("qol", "improvedchat", ns.BuildImprovedChatTab)   -- (Chat 0.6.33; UI-18 / UI-19 / UI-21)
-- (Chat 0.6.43; PS-56, #469) other addons that change the same thing (Modules.lua section 5d): a flag on the page and in one login
-- line; nothing here changes what the Chat Panel or Improved Chat do. Sources, each read 2026-11-08:
-- ElvUI: folder "ElvUI" (https://github.com/tukui-org/ElvUI : ElvUI/ElvUI.toc, Category "UI Overhaul"; module folders listed at
-- https://github.com/tukui-org/ElvUI/tree/main/ElvUI/Game/Shared/Modules and skins in ElvUI/Game/load_mainline.xml, read 2026-11-08).  Its chat module: Modules/Chat.
-- EllesmereUI ("EUI"): each module is its own addon folder (https://github.com/EllesmereGaming/EllesmereUI, every folder below has its
-- own <folder>.toc, read 2026-11-08).  EllesmereUIChat/EllesmereUIChat.toc (with
-- EUI_Chat_Skin.lua and EUI_Chat_Sidebar.lua).
-- Prat: folder "Prat-3.0" (https://github.com/Legacy-of-Sylvanaar/prat-3-0 : Prat-3.0.toc at the root; WowAce, https://www.wowace.com/projects/prat-3-0:
-- "made up of 30+ smaller modules which each provide additional functionality" to chat).
if ns.RegisterConflict then
    ns.RegisterConflict({ part = "chatpanel", label = "Chat Panel", addons = { "ElvUI", "EllesmereUIChat" }, what = "the chat window",
        on = function() return C.On() end })
    ns.RegisterConflict({ part = "improvedchat", label = "Improved Chat", addons = { "ElvUI", "EllesmereUIChat" }, what = "the chat window",
        on = function() return C.ImprovedOn() end })
    ns.RegisterConflict({ part = "improvedchat", label = "Improved Chat", addons = { "Prat-3.0" }, what = "how the chat behaves",
        on = function() return C.ImprovedOn() end })
end
-- (Chat 0.6.40; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 6.6) theme scope of the Chat Panel page, under the Blizzard Reskin tab's scope (core Theme.lua). Plumbing only:
-- nothing paints with it yet and no page edits it (the UI comes with the module moves).
local TS = ns.Theme and ns.Theme.RegisterScope
if TS then
    TS({ id = "reskin.chatpanel", label = "Chat Panel", parent = "reskin" })
end

ns.RegisterLauncher({ "chat", "Chat Panel", "Open the Chat Panel settings (also /xui chat settings)", function() C.OpenSettings() end, order = 40 })
ns.RegisterLauncher({ "improvedchat", "Improved Chat", "Open the Improved Chat settings", function() C.OpenSettings("improved") end, order = 41 })
