-------------------------------------------------------------------------------
-- XayaUI_Options/MinimapTab.lua : the settings page Settings > Minimap Button (the button itself is core's XayaUI/MinimapButton.lua).
-- Code moved unchanged from XayaUI/MinimapButton.lua (bundle 1 round 7, REQUEST-LOG A23 SD-58 / SD-62: the minimap button stays in core
-- as her one V34 exception, "The Options-only builder for the minimap page still moves to Options"): the game reads it only when the
-- settings window's code loads, never at login. It reads and writes the same saved table (ns.minimapDB, CueRulesDB.minimap) and asks
-- core to place the button again (ns.Minimap_Refresh), as before. The two small helpers below read the same fields as core's own
-- (MinimapButton.lua Shown / Available): a row is shown unless switched off, and a row whose feature is off has no switch.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (this addon depends on it: ## Dependencies: XayaUI)

local function DB() return ns.minimapDB end
local MIN_SIZE, MAX_SIZE = ns.MINIMAP_MIN_SIZE or 16, ns.MINIMAP_MAX_SIZE or 48
local BASE_SIZE = (ns.MINIMAP_DEFAULTS and ns.MINIMAP_DEFAULTS.size) or 31   -- the button's default size (core's BASE_SIZE, the same 31)
local function Shown(db, key) return db.entries[key] ~= false end
local function Available(e)
    if type(e.available) ~= "function" then return true end
    local ok, v = pcall(e.available)
    return ok and v ~= false and v ~= nil
end

function ns.BuildMinimapTab(Notify)
    if not DB() then return nil end
    ns.Minimap_Changed = function() if Notify then Notify() end end
    local function g(k) return function() return DB()[k] end end
    local function s(k) return function(_, v) DB()[k] = v; ns.Minimap_Refresh() end end
    local args = {
        n = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "A button on the minimap. Left-click opens a small list of buttons for the features you pick below; right-click opens this window; drag it to move it around the minimap." },
        show = { type = "toggle", order = 1, name = "Show the minimap button", width = "full", get = function() return not DB().hide end, set = function(_, v) DB().hide = not v; ns.Minimap_Refresh() end },
        -- (core 0.6.68; REQUEST-LOG A16 CR-6 / CR-7, Xaya: "create the option in each feature to choose whether it's a sidebar or minimap
        -- icon display; default to having sidebar on if minimap is turned off")
        where = { type = "select", order = 1.5, name = "Show it in", values = { MINIMAP = "Minimap", SIDEBAR = "Chat sidebar", BOTH = "Both" }, sorting = { "MINIMAP", "SIDEBAR", "BOTH" },
            desc = "The chat sidebar is part of QoL > Improved Chat. With nothing chosen, the sidebar holds the button while the minimap button is turned off.",
            get = function() return ns.Minimap_Where() end, set = function(_, v) DB().where = v; if v ~= "SIDEBAR" then DB().hide = false end; ns.Minimap_Refresh() end },
        lock = { type = "toggle", order = 2, name = "Lock the button's position", disabled = function() return DB().hide end, get = g("locked"), set = function(_, v) DB().locked = v end },
        close = { type = "toggle", order = 3, name = "Close the list after a choice", disabled = function() return DB().hide end, get = g("closeOnClick"), set = function(_, v) DB().closeOnClick = v end },
        angle = { type = "range", order = 4, name = "Position (degrees around the minimap)", min = 0, max = 359, step = 1, disabled = function() return DB().hide end, get = g("angle"), set = s("angle") },
        size = { type = "range", order = 4.5, name = "Button size (pixels)", min = MIN_SIZE, max = MAX_SIZE, step = 1,
            desc = "Sets the button size, from " .. MIN_SIZE .. " to " .. MAX_SIZE .. " pixels (default " .. BASE_SIZE .. ").",
            disabled = function() return DB().hide end, get = function() return DB().size or BASE_SIZE end,
            set = function(_, v) DB().size = math.max(MIN_SIZE, math.min(MAX_SIZE, tonumber(v) or BASE_SIZE)); ns.Minimap_Refresh() end },
        iconH = { type = "header", order = 5, name = "Button icon" },
        iconPreview = { type = "description", order = 5.1, width = "half", name = "",
            image = function() return (ns.Minimap_ResolveIcon(DB().iconOverride)) end, imageWidth = 32, imageHeight = 32 },
        icon = { type = "input", order = 5.2, width = "double", name = "Icon override (file ID, icon name, or spell:ID)",
            desc = "Sets the button's icon: a file ID, an icon name, spell:ID or a texture path. Leave empty for the built-in icon.",
            disabled = function() return DB().hide end,
            get = function() return DB().iconOverride or "" end,
            set = function(_, v) DB().iconOverride = tostring(v or ""):gsub("[%c|]", ""):gsub("^%s+", ""):gsub("%s+$", ""); ns.Minimap_Refresh(); if Notify then Notify() end end },
        iconReset = { type = "execute", order = 5.3, width = "half", name = "Reset",
            desc = "Back to the built-in icon.", disabled = function() return DB().hide or (DB().iconOverride or "") == "" end,
            func = function() DB().iconOverride = ""; ns.Minimap_Refresh(); if Notify then Notify() end end },
        iconNote = { type = "description", order = 5.4, width = "full", fontSize = "small",
            name = function() local _, note = ns.Minimap_ResolveIcon(DB().iconOverride); return "Using: " .. note .. ". A wrong ID or path can show a green square or an empty button; clear the box or press Reset." end },
        entries = { type = "group", name = "Buttons in the list", order = 10, inline = true, disabled = function() return DB().hide end, args = {} },
    }
    for i, e in ipairs(ns.Launchers()) do
        args.entries.args[e[1]] = { type = "toggle", order = i, name = e[2], desc = e[3],
            hidden = function() return not Available(e) end,   -- (core 0.6.49: its feature is off)
            get = function() return Shown(DB(), e[1]) end,
            set = function(_, v) DB().entries[e[1]] = v and true or false; ns.Minimap_Refresh() end }
    end
    return { type = "group", name = "Minimap Button", order = 12, args = args }
end
