-------------------------------------------------------------------------------
-- MouseTracker.lua : the right-click tracker, /xui debug mouse on | off (REQUEST-LOG A23 SD-33 / SD-34).
-- Xaya 2026-11-10, her words (SD-33): "is there a way to track right mouse click drag attempts and see what might be interfereing with
-- them?"; her answer to building it (SD-34): "Yes, in bundle 1 (Recommended)".
--
-- What the player gets: while it is on, each right-click that lands on a frame instead of the game world prints one line naming that
-- frame, whether it takes clicks and where it was made. A right-click on the game world prints nothing. Turning it off prints one
-- line with the count ("N right-clicks checked, M caught by other frames").
--
-- Game facts used (docs/reference/api/, 12.1.5):
--   GLOBAL_MOUSE_DOWN (button: cstring) · SynchronousEvent · SystemInfo                                  (events.md:674)
--   GetMouseFoci() → region: table<ScriptRegion>                                                        (globals.md:214)
--   GetDebugName(preferParentKey: bool = false) → debugName: string · ConstSecretAccessor, SecretArguments=AllowedWhenUntainted
--                                                                                                       (widgets.md:22)
--   IsMouseClickEnabled() → enabled: bool                                                               (widgets.md:211)
--   GetSourceLocation() → location: string · SecretReturnsForAspect=[SecretAspect.ObjectDebug]          (widgets.md:173)
--   IsForbidden() (the game's guard on frames addons may not read; INFERENCE from Blizzard's own code, which tests it first)
--   issecretvalue(value) → isSecret: bool                                                               (globals.md:760)
-- INFERENCE (not documented): the first entry of GetMouseFoci() is the frame on top, the one that gets the click; over the open
-- world (a corpse, an NPC, the ground) it is WorldFrame. GetSourceLocation may give nothing (a frame made from Lua without a debug
-- location), and both names may be secret on a frame the game protects: the line then says so and never shows a guess.
--
-- V14 (off costs nothing): off by default and after every /reload (nothing is saved). While off, no frame exists and no event is
-- registered; the one frame is made the first time it is turned on, and turning it off unregisters its one event. Turned off, the
-- frame stays (the game cannot delete frames) with no event and no script that runs. Level: the file is read at login like every
-- core file (its function definitions only).
-- V26 (combat lock): exempt, read-only (Modules.lua section 6b, key "mouse"): it changes nothing and only reads which frame is under
-- the cursor, so it can be turned on and off in combat, when right-drag trouble is most likely to be seen.
-- V24 / V25 / V27 cost and control: one event, GLOBAL_MOUSE_DOWN, only while on. Per mouse press: one string compare (other buttons
-- return at once). Per right-click: GetMouseFoci (the game hands back a table) and one compare with WorldFrame; only when another
-- frame is on top are its three reads made and one line built and printed. No OnUpdate, no timer, no loop, no table of XayaUI's own
-- per press. The frame is hidden, never takes the mouse or the keyboard, and the press itself is never caught or changed: the game
-- runs the click and the camera drag exactly as without it.
-------------------------------------------------------------------------------
local _, ns = ...
local issecret = issecretvalue or function() return false end

local on, frame = false, nil
local checked, caught = 0, 0

-- a value read from the frame, as text the line can carry ("|" doubled so the chat shows it as written); nil when there is none
local function Readable(v)
    if issecret(v) then return nil, true end   -- tested first: a secret is never compared or turned into text
    if v == nil then return nil, false end
    v = tostring(v)
    if v == "" then return nil, false end
    return (v:gsub("|", "||")), false
end

local function Describe(f)
    local okF, forbidden = pcall(f.IsForbidden, f)
    if okF and forbidden then
        return "right-click went to a frame the game protects (addons can't read its name or where it was made), not the game world."
    end
    local name, nameHidden, src, srcHidden
    local okN, rawName = pcall(f.GetDebugName, f)
    if okN then name, nameHidden = Readable(rawName) end
    local okC, clicks = pcall(f.IsMouseClickEnabled, f)
    local okS, rawSrc = pcall(f.GetSourceLocation, f)
    if okS then src, srcHidden = Readable(rawSrc) end
    local who = name or (nameHidden and "a frame whose name the game hides" or "a frame with no name")
    local takes = (okC and clicks == true and "yes") or (okC and clicks == false and "no") or "unknown"
    local where = src and ("made in " .. src)
        or (srcHidden and "the game hides where it was made") or "the game does not say where it was made"
    return ("right-click went to %s, not the game world. Takes clicks: %s; %s."):format(who, takes, where)
end

local function OnEvent(_, _, button)
    if button ~= "RightButton" or not on then return end
    checked = checked + 1
    local foci = GetMouseFoci and GetMouseFoci()
    local top = foci and foci[1]
    -- the game world on top (or nothing under the cursor) prints nothing: no spam while she plays
    if top == nil or top == WorldFrame then return end
    caught = caught + 1
    ns.Print(Describe(top))
end

local function TurnOn()
    if on then ns.Print("the right-click tracker is already on. Type /xui debug mouse off to stop it."); return end
    if not frame then
        frame = CreateFrame("Frame")
        frame:Hide()   -- never drawn; events still reach a hidden frame
        frame:SetScript("OnEvent", OnEvent)
    end
    checked, caught = 0, 0
    on = true
    frame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    ns.Print("the right-click tracker is on: each right-click that lands on a frame instead of the game world prints one line naming that frame. Type /xui debug mouse off to stop it (a /reload also stops it).")
end

local function TurnOff()
    if not on then ns.Print("the right-click tracker is already off."); return end
    on = false
    if frame then frame:UnregisterEvent("GLOBAL_MOUSE_DOWN") end
    ns.Print(("the right-click tracker is off. %d %s checked, %d caught by other frames."):format(
        checked, checked == 1 and "right-click" or "right-clicks", caught))
end

-- /xui debug mouse [on|off] (Core.lua CORE_DEBUG). Exempt from the combat lock: it runs at once, in combat too.
function ns.MouseTrackerCommand(arg)
    local word = tostring(arg or ""):lower():match("^%s*(%S*)")
    local function run()
        if word == "on" then TurnOn()
        elseif word == "off" then TurnOff()
        else
            ns.Print(("the right-click tracker is %s. Type /xui debug mouse on or /xui debug mouse off."):format(on and "on" or "off"))
        end
    end
    if ns.CombatLock then ns.CombatLock("mouse", run) else run() end
end
function ns.MouseTrackerOn() return on end   -- (tests)
