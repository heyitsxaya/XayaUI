-- tests/harness/scenario.lua : one play session in the stand-in world (Lua 5.1). Called by run.py once per combination of addons.
-- Steps: start up (load, ADDON_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD) -> five seconds of frames -> the everyday events with
-- realistic payloads -> a fight (PLAYER_REGEN_DISABLED then the lockdown, events, frames, lockdown off then PLAYER_REGEN_ENABLED) ->
-- every /xui command -> every minimap row -> open the settings window and touch every option as the game's AceConfigDialog does
-- (read every label, state, list, and value, but no value of an option it hides; write back the value it already has) ->
-- close it -> log out (saved variables checked). Each step is labelled so the report says where an error happened.
return function(W, L, opts)
local S = { steps = {}, step = "start", stats = {} }
local function step(name) S.step = name; S.steps[#S.steps + 1] = { name = name, errors = #W.errors } end
local function ns() return rawget(_G, "XayaUI_NS") end

-------------------------------------------------------------------------------
step("load")
L.startup()
step("login")
W.fire("PLAYER_LOGIN")
W.fire("PLAYER_ENTERING_WORLD", true, false)
W.fire("SPELLS_CHANGED")
W.fire("PLAYER_TALENT_UPDATE")
W.fire("TRAIT_CONFIG_UPDATED", 1)
W.fire("UPDATE_CHAT_WINDOWS")
W.tick(0.1, 50)
if opts.quick then   -- a plain reload: start up, wait, log out (finds settings that change on every reload by themselves)
  step("logout")
  S.saved, S.saveIssues = L.logout()
  S.step = "done"
  return S
end

-------------------------------------------------------------------------------
step("everyday events")
local EVENTS = {
  { "UNIT_AURA", "player", { isFullUpdate = true } },
  { "UNIT_AURA", "target", { isFullUpdate = true } },
  { "UNIT_AURA", "player", { addedAuras = { { auraInstanceID = 7, spellId = 203819, name = "Demon Spikes", isHelpful = true, duration = 6, expirationTime = 1006, applications = 1, sourceUnit = "player", icon = 1344645 } } } },
  { "SPELL_UPDATE_COOLDOWN" }, { "SPELL_UPDATE_CHARGES" }, { "SPELL_UPDATE_USABLE" }, { "ACTIONBAR_UPDATE_COOLDOWN" },
  { "UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-1-1-1-203720-0000", 203720 },
  { "UNIT_SPELLCAST_START", "player", "Cast-3-1-1-1-203720-0001", 203720 },
  { "UNIT_SPELLCAST_STOP", "player", "Cast-3-1-1-1-203720-0001", 203720 },
  { "PLAYER_TARGET_CHANGED" }, { "PLAYER_FOCUS_CHANGED" }, { "GROUP_ROSTER_UPDATE" },
  { "PLAYER_SPECIALIZATION_CHANGED", "player" }, { "ACTIVE_TALENT_GROUP_CHANGED", 1, 2 }, { "TRAIT_CONFIG_UPDATED", 1 },
  { "ZONE_CHANGED_NEW_AREA" }, { "ZONE_CHANGED" }, { "ZONE_CHANGED_INDOORS" }, { "UPDATE_SHAPESHIFT_FORM" },
  { "UNIT_POWER_UPDATE", "player", "FURY" }, { "UNIT_POWER_FREQUENT", "player", "FURY" }, { "UNIT_HEALTH", "player" }, { "UNIT_MAXHEALTH", "player" },
  { "BAG_UPDATE_DELAYED" }, { "PLAYER_MONEY" }, { "FRIENDLIST_UPDATE" }, { "BN_FRIEND_INFO_CHANGED" }, { "PLAYER_EQUIPMENT_CHANGED", 1, false },
  { "UPDATE_INVENTORY_DURABILITY" }, { "CURRENCY_DISPLAY_UPDATE" }, { "PLAYER_MOUNT_DISPLAY_CHANGED" }, { "PLAYER_UPDATE_RESTING" },
  { "CHAT_MSG_SAY", "hello there", "Friend-Area52", "Common", "", "Friend", "", 0, 0, "", 0, 11, "Player-1234-0F00", 0, false, false, false },
  { "CHAT_MSG_WHISPER", "a private hello", "Friend-Area52", "Common", "", "Friend", "", 0, 0, "", 0, 12, "Player-1234-0F00", 0, false, false, false },
  { "CHAT_MSG_GUILD", "guild hello", "Guildie-Area52", "Common", "", "Guildie", "", 0, 0, "", 0, 13, "Player-1234-0F01", 0, false, false, false },
  { "CHAT_MSG_PARTY", "pull in 5", "Tank-Area52", "Common", "", "Tank", "", 0, 0, "", 0, 14, "Player-1234-0F02", 0, false, false, false },
  { "CHAT_MSG_SYSTEM", "Xaya has come online." },
  { "CHAT_MSG_ADDON", "XUINOTE", "D|ab12|1|1|hello", "WHISPER", "Friend-Area52" },
  { "UPDATE_CHAT_WINDOWS" }, { "UPDATE_FLOATING_CHAT_WINDOWS" }, { "UI_SCALE_CHANGED" }, { "DISPLAY_SIZE_CHANGED" },
  { "CVAR_UPDATE", "uiScale", "1" }, { "LOSS_OF_CONTROL_ADDED", 1 }, { "LOSS_OF_CONTROL_UPDATE" }, { "PLAYER_STARTED_MOVING" }, { "PLAYER_STOPPED_MOVING" },
  { "COOLDOWN_VIEWER_DATA_LOADED" }, { "ENCOUNTER_START", 3000, "Boss", 16, 20 }, { "ENCOUNTER_END", 3000, "Boss", 16, 20, 1 },
  { "CHALLENGE_MODE_START", 500 }, { "CHALLENGE_MODE_COMPLETED" }, { "PLAYER_DEAD" }, { "PLAYER_ALIVE" }, { "PLAYER_UNGHOST" },
}
for _, e in ipairs(EVENTS) do W.fire(unpack(e)) end
W.tick(0.1, 20)
-- every other event any of our frames registered, with no payload: the game always sends one, so an error here is a WARNING
-- (reported separately), not a failure
step("other registered events (no payload)")
S.noPayloadStart = #W.errors
local fired = {}
for _, e in ipairs(EVENTS) do fired[e[1]] = true end
local others = {}
for ev in pairs(W.registeredEvents()) do if not fired[ev] and ev ~= "PLAYER_LOGOUT" and ev ~= "ADDON_LOADED" then others[#others + 1] = ev end end
table.sort(others)
for _, ev in ipairs(others) do W.fire(ev) end
S.noPayloadEnd = #W.errors
S.otherEvents = others
W.tick(0.1, 10)

-------------------------------------------------------------------------------
step("combat")
-- (round 11, scope item 1) in the game's order (world.lua W.enterCombat / W.leaveCombat; warcraft.wiki.gg API InCombatLockdown):
-- PLAYER_REGEN_DISABLED is handled while InCombatLockdown() is still false, the lockdown begins after it and ends before
-- PLAYER_REGEN_ENABLED. (Before round 11 this step set the lockdown first, so every combat-start handler ran locked down.)
W.enterCombat()
for _, e in ipairs(EVENTS) do if e[1]:match("^UNIT_") or e[1]:match("^SPELL_") then W.fire(unpack(e)) end end
W.tick(0.1, 30)
W.leaveCombat()
W.tick(0.1, 20)

-------------------------------------------------------------------------------
step("slash commands")
-- (core 0.6.50: the diagnostic commands are /xui debug <name>; "status" and "auras" are shortcuts printed in chat; "debug window" is the
-- old name of "debug loader")
local commands = { "debug status", "debug", "debug icons", "debug debuffs", "debug debuffs target 1234", "debug probe 203720", "debug probe ids",
  "debug talents", "debug talents status", "debug model", "debug model 203819", "debug tracker status", "debug mods", "debug groups", "debug loc",
  "debug timing", "debug perf", "debug perf on", "debug perf off", "debug perf ui", "debug perf ui", "unlock", "unlock", "debug media",
  "console", "console", "bug", "chat", "chat status", "chat wrap", "chat history", "chat history", "chat move", "chat move", "panel", "debug chatprobe",
  "privacy", "privacy", "data", "notes", "notes", "debug gamemenu", "cursor", "cursor highlight", "cursor trail", "chat settings", "panel",
  "debug loader", "debug auras", "debug widthprobe off", "debug map", "status", "auras", "auras target debuffs", "debug window", "debug nosuch",
  "nonsense-command" }
S.commands = 0
local xui = SlashCmdList and SlashCmdList["XAYAUI"]
if xui then
  for _, c in ipairs(commands) do
    S.step = "slash /xui " .. c
    local before = #W.printed
    W.safecall(xui, c); S.commands = S.commands + 1; W.tick(0.1, 2)
    -- A feature command whose addon IS loaded but never registered it (Modules.lua ns.ModuleMissingText) is a bug, not a message.
    for i = before + 1, #W.printed do
      if tostring(W.printed[i]):find("the command was never registered", 1, true) then
        W.errors[#W.errors + 1] = "/xui " .. c .. ": " .. tostring(W.printed[i])
      end
    end
  end
end
-- every other slash command our addons added (their names start with XUI or XAYA)
for key, fn in pairs(SlashCmdList or {}) do
  if key ~= "XAYAUI" and (key:match("^XUI") or key:match("^XAYA")) then
    for _, arg in ipairs({ "", "status", "help" }) do S.step = "slash " .. key .. " " .. arg; W.safecall(fn, arg); S.commands = S.commands + 1 end
  end
end
W.tick(0.1, 5)

-------------------------------------------------------------------------------
step("minimap rows")
S.launchers = 0
local N = ns()
if N and N.Launchers then
  for _, e in ipairs(N.Launchers()) do
    S.step = "minimap row " .. tostring(e[1])
    if e[5] then W.safecall(e[5]) end
    if e[1] ~= "settings" then W.safecall(e[4]); W.safecall(e[4]) end   -- toggles: twice, back to where they were
    S.launchers = S.launchers + 1
  end
end

-------------------------------------------------------------------------------
step("settings window: open")
S.optionNodes, S.optionCalls, S.optionGets, S.optionHidden = 0, 0, 0, 0
if N and N.ToggleUI then W.safecall(N.ToggleUI) end
W.tick(0.1, 5)
step("settings window: every option")
-- (round 11, SD-119 / scope item 2) every option is read the way the game's settings window reads it: AceConfigDialog-3.0 (the copy in
-- XayaUI_Options/Libs/AceConfig-3.0/AceConfigDialog-3.0/AceConfigDialog-3.0.lua). Its FeedOptions asks CheckOptionHidden first
-- (:1128 "local hidden = CheckOptionHidden(v, options, path, appName)", then :1130 "if not hidden then") and only a shown control
-- has its get called (e.g. :1191, :1201, :1225); a hidden group's options are never fed at all (:961, :990, :1017, :1052 "if not inline and not
-- hidden then"; :1553 a selected path stops at a hidden group). CheckOptionHidden (:927-935) takes dialogHidden / guiHidden first,
-- then the member "hidden", which like get, set, func, confirm, validate and disabled is INHERITED (isInherited, :131-139): the last
-- one set on the way from the root to the option, called with the option's own info (GetOptionsMemberValue, :164-226). So: a hidden
-- option, or any option under a hidden group, has no get or set called here (before round 11 the harness called get on hidden options,
-- e.g. Editor.lua's game-sound rows on a rule with no game sound, an error the game cannot raise). Its other members (name, desc,
-- disabled, width, image, order, values, sorting) are still read, as before, so their code is still played. Counted: S.optionGets
-- (get calls made), S.optionHidden (options whose get the window would never call).
local APP = "CueRules"                                   -- (XayaUI_Options/Skin.lua APP: the name the window is registered under)
local INHERITED = { set = true, get = true, func = true, confirm = true, validate = true, disabled = true, hidden = true }
local LITERAL_STRING = { name = true, desc = true, icon = true, usage = true, width = true, image = true, fontSize = true, tooltipHyperlink = true }
local ALWAYS_LITERAL = { type = true, descStyle = true, imageWidth = true, imageHeight = true }
local NO_GET = { execute = true, description = true, header = true, group = true }
-- chain: the tables from the root to this option (the option last), as GetOptionsMemberValue walks them with GetSubOption
local function walk(node, path, chain, depth, hiddenAbove)
  if type(node) ~= "table" or depth > 40 then return end
  S.optionNodes = S.optionNodes + 1
  local root = chain[1]
  local handler
  for _, g in ipairs(chain) do handler = g.handler or handler end
  local info = { options = root, option = node, arg = node.arg, handler = handler, type = node.type, uiType = "dialog",
    uiName = "AceConfigDialog-3.0", appName = APP }
  info[0] = APP
  for i, k in ipairs(path) do info[i] = k end
  local where = table.concat(path, " > ")
  local function member(field)
    if not INHERITED[field] then return node[field] end
    local m
    for _, g in ipairs(chain) do if g[field] ~= nil then m = g[field] end end
    return m
  end
  local function call(field, ...)
    local f = member(field)
    local isCall = not ALWAYS_LITERAL[field] and (type(f) == "function" or (type(f) == "string" and not LITERAL_STRING[field]))
    if not isCall then return f end
    S.optionCalls = S.optionCalls + 1
    S.step = "option " .. where .. " [" .. field .. "]"
    local res
    if type(f) == "function" then res = { pcall(f, info, ...) }
    elseif handler and type(handler[f]) == "function" then res = { pcall(handler[f], handler, info, ...) }
    else res = { false, ("Method %s doesn't exist in handler for type %s"):format(f, field) } end   -- (AceConfigDialog :221 errors so)
    if not res[1] then W.errors[#W.errors + 1] = tostring(res[2]) .. "\n  at option " .. where .. " [" .. field .. "]"; return nil end
    return unpack(res, 2)
  end
  -- hidden first, as CheckOptionHidden (the root itself is never asked: the window feeds the root's options, not the root)
  local hidden = hiddenAbove
  if depth > 0 then
    local own = node.dialogHidden
    if own == nil then own = node.guiHidden end
    if own == nil then own = call("hidden") end
    hidden = hidden or (own and true or false)
  end
  call("name"); call("desc"); call("disabled"); call("width"); call("image"); call("order")
  local values = call("values")
  if node.sorting then call("sorting") end
  if not NO_GET[node.type] and member("get") ~= nil then
    if hidden then
      S.optionHidden = S.optionHidden + 1
    else
      local canSet = opts.writeBack and member("set") ~= nil
      S.optionGets = S.optionGets + 1
      if node.type == "multiselect" then
        if type(values) == "table" then for k in pairs(values) do local v = call("get", k); if canSet then call("set", k, v) end end end
      elseif node.type == "color" then
        local r, g, b, a = call("get")
        if canSet and r then call("set", r, g, b, a) end
      else
        local v = call("get")
        if canSet and v ~= nil then call("set", v) end
      end
    end
  end
  if type(node.args) == "table" then
    local keys = {}
    for k in pairs(node.args) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
      local p, c = {}, {}
      for i, x in ipairs(path) do p[i] = x end
      for i, x in ipairs(chain) do c[i] = x end
      p[#p + 1] = k
      c[#c + 1] = node.args[k]
      walk(node.args[k], p, c, depth + 1, hidden)
    end
  end
end
N = ns()
-- with XayaUI_Options switched on, the window must have loaded and its option table must build; anything else is a failure
local optionsOn = C_AddOns.GetAddOnEnableState("XayaUI_Options") == 2 and C_AddOns.DoesAddOnExist("XayaUI_Options")
local okB, built = false, nil
if N and N.BuildOptionsTable then okB, built = pcall(N.BuildOptionsTable) end
if type(built) == "table" then walk(built, {}, { built }, 0, false)
else
  S.noOptions = true
  if optionsOn then
    W.errors[#W.errors + 1] = "the settings window did not build: " .. (N and N.BuildOptionsTable and tostring(built) or "XayaUI_Options never loaded (ns.BuildOptionsTable missing)")
  end
end
step("settings window: close")
if N and N.ToggleUI then W.safecall(N.ToggleUI) end
W.tick(0.1, 10)

-------------------------------------------------------------------------------
step("logout")
S.saved, S.saveIssues = L.logout()
S.step = "done"
return S
end
