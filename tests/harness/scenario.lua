-- tests/harness/scenario.lua : one play session in the stand-in world (Lua 5.1). Called by run.py once per combination of addons.
-- Steps: start up (load, ADDON_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD) -> five seconds of frames -> the everyday events with
-- realistic payloads -> a fight (combat lockdown on, events, frames, off) -> every /xui command -> every minimap row -> open the
-- settings window and touch every option (read every label, state, list, and value; write back the value it already has) ->
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
W.combat = true
W.fire("PLAYER_REGEN_DISABLED")
for _, e in ipairs(EVENTS) do if e[1]:match("^UNIT_") or e[1]:match("^SPELL_") then W.fire(unpack(e)) end end
W.tick(0.1, 30)
W.combat = false
W.fire("PLAYER_REGEN_ENABLED")
W.tick(0.1, 20)

-------------------------------------------------------------------------------
step("slash commands")
local commands = { "status", "debug", "icons", "debuffs", "debuffs target 1234", "probe 203720", "probe ids", "talents", "talents status", "model",
  "model 203819", "tracker status", "mods", "groups", "loc", "timing", "perf", "perf on", "perf off", "perf ui", "perf ui", "unlock", "unlock", "media",
  "console", "console", "bug", "chat", "chat status", "chat wrap", "chat history", "chat history", "chat move", "chat move", "panel", "chatprobe",
  "privacy", "privacy", "data", "notes", "notes", "gamemenu", "cursor", "nonsense-command" }
S.commands = 0
local xui = SlashCmdList and SlashCmdList["XAYAUI"]
if xui then
  for _, c in ipairs(commands) do S.step = "slash /xui " .. c; W.safecall(xui, c); S.commands = S.commands + 1; W.tick(0.1, 2) end
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
S.optionNodes, S.optionCalls = 0, 0
if N and N.ToggleUI then W.safecall(N.ToggleUI) end
W.tick(0.1, 5)
step("settings window: every option")
local function walk(node, path, root, depth)
  if type(node) ~= "table" or depth > 40 then return end
  S.optionNodes = S.optionNodes + 1
  local info = { options = root, option = node, arg = node.arg, handler = node.handler, type = node.type, uiType = "dialog", uiName = "CueRules" }
  for i, k in ipairs(path) do info[i] = k end
  local function call(field, ...)
    local f = node[field]
    if type(f) == "function" then
      S.optionCalls = S.optionCalls + 1
      S.step = "option " .. table.concat(path, " > ") .. " [" .. field .. "]"
      local res = { pcall(f, info, ...) }
      if not res[1] then W.errors[#W.errors + 1] = tostring(res[2]) .. "\n  at option " .. table.concat(path, " > ") .. " [" .. field .. "]"; return nil end
      return unpack(res, 2)
    end
    return f
  end
  call("name"); call("desc"); call("hidden"); call("disabled"); call("width"); call("image"); call("order")
  local values = call("values")
  if node.sorting then call("sorting") end
  if node.get and node.type ~= "execute" and node.type ~= "description" and node.type ~= "header" and node.type ~= "group" then
    if node.type == "multiselect" then
      if type(values) == "table" then for k in pairs(values) do local v = call("get", k); if opts.writeBack and node.set then call("set", k, v) end end end
    elseif node.type == "color" then
      local r, g, b, a = call("get")
      if opts.writeBack and node.set and r then call("set", r, g, b, a) end
    else
      local v = call("get")
      if opts.writeBack and node.set and v ~= nil then call("set", v) end
    end
  end
  if type(node.args) == "table" then
    local keys = {}
    for k in pairs(node.args) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
      local p = {}
      for i, x in ipairs(path) do p[i] = x end
      p[#p + 1] = k
      walk(node.args[k], p, root, depth + 1)
    end
  end
end
N = ns()
local built = N and N.BuildOptionsTable and select(2, pcall(N.BuildOptionsTable))
if type(built) == "table" then walk(built, {}, built, 0) else S.noOptions = true end
step("settings window: close")
if N and N.ToggleUI then W.safecall(N.ToggleUI) end
W.tick(0.1, 10)

-------------------------------------------------------------------------------
step("logout")
S.saved, S.saveIssues = L.logout()
S.step = "done"
return S
end
