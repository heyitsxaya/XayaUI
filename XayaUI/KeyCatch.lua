-------------------------------------------------------------------------------
-- KeyCatch.lua (XayaUI 0.6.85): the one way a XayaUI window takes keys, and the one way a XayaUI text box lets go of the keyboard.
-- Xaya 2026-11-08 (docs/process/REQUEST-LOG-session-014bN6tUDLJ6T742DewZDg1s.md row 56, her words): "WHY DOES THE ADDON KEEP
-- PREVENTING ME FROM SCREENSHOTTING".
--
-- Game facts (docs/reference/api/widgets.md, Blizzard's generated SimpleFrameAPIDocumentation 12.1.5; warcraft.wiki.gg, read
-- 2026-11-08):
--   EnableKeyboard(enable: bool = false) · IsProtectedFunction, SecretArguments=NotAllowed · SimpleFrameAPI
--   SetPropagateKeyboardInput(propagate: bool) · HasRestrictions, SecretArguments=AllowedWhenUntainted · SimpleFrameAPI
--   GetPropagateKeyboardInput() -> propagate: bool · SimpleFrameAPI
--   wiki (API Frame SetPropagateKeyboardInput): "#nocombat", "This cannot be called while in combat" (restricted since 10.1.5);
--     "Keyboard bindings are handled by the WorldFrame, so if any non-propagating keyboard-enabled frame is visible, no keyboard
--     bindings can be triggered" (the screenshot key, PRINTSCREEN, and movement are key bindings); "You can call this function from
--     OnKeyDown script handlers to consume only some keyboard events" (so the flag set inside OnKeyDown counts for that key).
--   wiki (API InCombatLockdown): "Combat lockdown begins after the PLAYER_REGEN_DISABLED event fires".
--   GLOBAL_MOUSE_DOWN (button: cstring) · SynchronousEvent (events.md 674).
--   INFERENCE (not documented): a keyboard-enabled frame consumes keys until SetPropagateKeyboardInput(true) is called on it (the
--     EnableKeyboard wiki page: such a frame will "prevent all keyboard bindings from functioning while it is visible"); an edit box
--     with keyboard focus takes every key, the screenshot key included.
--
-- What went wrong (three windows set the flag by hand): the flag was only set from inside OnKeyDown and only out of combat. In combat
-- nothing could set it, so it stayed at what it was: false (every key, movement and PRINTSCREEN included, kept by the window) when the
-- window was opened and no key was pressed yet, or when the last key before the fight was one the window used (Delete in the settings
-- window, an arrow in the mover view). A Lua error in a key handler also left the flag unset.
--
-- ns.KeyCatch(frame, handler): handler(frame, key, inCombat) returns true when it used the key.
--   * the flag rests at true: every key goes on to the game. It is set to true when the window is shown (out of combat), when it is
--     set up, after any key it did not use, on the next frame after a key it used, and at PLAYER_REGEN_DISABLED (before the lockdown);
--   * a key the handler used is held for that key only (out of combat); PRINTSCREEN is never held;
--   * in combat the flag is never touched (restricted); the handler still runs and says what it would do (inCombat = true);
--   * the keyboard is switched on only while the window is shown and out of combat (EnableKeyboard is a protected function: never
--     called in combat); the result's SetActive(false) lets go of the keyboard (a recycled AceGUI window that another addon gets);
--   * a window first set up in combat is hooked only when combat ends (review R1: an OnKeyDown script turns its keyboard on, and
--     its flag could not be set, so it held every key until the fight ended).
-- ns.KeyFocusGuard(editBox, opts): a text box never keeps the keyboard after the player is done with it:
--   * no focus on show (SetAutoFocus(false)); Escape clears the focus (a box's own Escape script is kept); Enter clears it in a
--     one-line box that has no Enter script of its own;
--   * a mouse click outside opts.within (default: the box) clears it (GLOBAL_MOUSE_DOWN);
--   * the box or its window (opts.window, default: its top frame under UIParent) hiding clears it (the game also drops the focus of a
--     hidden box, Options' Skin.lua search box notes; cleared here as well, so it never depends on that);
--   * a fight starting clears it (review R23);
--   * opts.onDone(box) runs after Enter / Escape / a click outside / a fight starting cleared it.
--   * (A23 SD-12) the click / fight watcher's events are registered only while a guarded box has the keyboard (the box's
--     OnEditFocusGained / OnEditFocusLost, hooked: a box's own focus scripts must be set before it is guarded); with no box focused, a
--     click costs nothing. warcraft.wiki.gg (UIHANDLER OnEditFocusGained / OnEditFocusLost): "Fires when the frame gains / loses
--     keyboard focus" (INFERENCE: SetFocus / ClearFocus and a click count, as for Blizzard's own boxes).
-- V14: nothing is made until the first window or box asks for it (the event frames are created then).
--
-- (XayaUI 0.6.85, the review's should-fix items, 2026-11-09)
-- * The screenshot key is found by what it does, not by its name: Blizzard's own key-taking frames read the binding first
--   (Gethe/wow-ui-source, live branch, read 2026-11-09: StaticPopup.lua:792-797 `local bindingKey = GetBindingFromClick(key);` ...
--   `elseif bindingKey == "SCREENSHOT" then RunBinding("SCREENSHOT"); return;`; CinematicFrame.lua:117 the same read). Those frames
--   keep every key, so they run the screenshot themselves; a KeyCatch window passes it on instead (the game takes the picture). A key
--   bound to SCREENSHOT (or named PRINTSCREEN) never reaches the window's handler and is never held, whatever she bound it to.
--   GetBindingFromClick is not in the repo's API reference (docs/reference/api: absent); warcraft.wiki.gg (API GetBindingFromClick,
--   read 2026-11-09): "command = GetBindingFromClick(keyOrButton)", returns "string - The command that keyOrButton is bound to"; what
--   it returns for an unbound key and how modifiers count are not documented. INFERENCE: nil or "" means unbound, and the held
--   modifiers count (Blizzard passes the bare OnKeyDown key). Fails safe: when the binding cannot be read, it is "unknown" (below).
-- * In combat a key the window used would ALSO reach the game (the pass-on flag cannot be changed in combat, so it rests at true).
--   A key must never do two things (V24): in combat the handler runs only for a key the game itself has no binding for (then the
--   game does nothing with it); a key that is bound, or whose binding cannot be read, is the game's alone and the window does not act
--   on it. Out of combat nothing changes: a used key is held for that key only.
-- * ns.KeyFocusGuard(box, { enterLetsGo = true }): Enter lets go also in a box that has an Enter script of its own (run after it; for
--   boxes XayaUI does not write, AceGUI's EditBox in the settings window: XayaUI_Options/Skin.lua). ns.KeyFocusRelease(box) stops
--   guarding a box that is handed back (AceGUI recycles its widgets for other addons).
-------------------------------------------------------------------------------
local _, ns = ...

local NEVER_HOLD = { PRINTSCREEN = true }
local catches = setmetatable({}, { __mode = "k" })   -- frame -> its state
local guarded = setmetatable({}, { __mode = "k" })   -- edit box -> its options
local windowHooked = setmetatable({}, { __mode = "k" })
local combatWatch, mouseWatch

local function Fighting() return InCombatLockdown and InCombatLockdown() and true or false end
-- what the game does with this key (held modifiers included): the action's name, false = nothing (unbound), nil = unknown
local function Binding(key)
    if type(key) ~= "string" or not GetBindingFromClick then return nil end
    local ok, action = pcall(GetBindingFromClick, key)
    if not ok then return nil end
    if action == nil or action == "" then return false end
    return type(action) == "string" and action or nil
end
ns.KeyBinding = Binding
local function Report(e) local h = geterrorhandler and geterrorhandler(); if h then pcall(h, e) end end
-- the resting state: every key goes on to the game
local function Pass(f)
    if f.SetPropagateKeyboardInput then pcall(f.SetPropagateKeyboardInput, f, true) end
end
-- out of combat only: keyboard on while active and shown, the flag at rest either way
local function Apply(f, kc)
    if Fighting() or not kc.ready then return end
    Pass(f)
    local want = kc.active and f:IsShown() and true or false
    if f.EnableKeyboard and kc.kb ~= want then f:EnableKeyboard(want); kc.kb = want end
end

local function WatchCombat()
    if combatWatch then return end
    combatWatch = CreateFrame("Frame")
    combatWatch:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
    combatWatch:SetScript("OnEvent", function(_, ev)
        for f, kc in pairs(catches) do
            if not kc.ready then
                if ev == "PLAYER_REGEN_ENABLED" then kc.setup() end   -- a window first made in combat: set up now (review R1)
            -- (A23 SD-12) a window that was let go with its keyboard off (the settings window's frame, now another addon's) is not touched
            elseif kc.active or kc.kb or kc.held then
                -- before the lockdown begins: the flag goes back to true, so no key is kept from the game in the fight
                if ev == "PLAYER_REGEN_DISABLED" then kc.held = nil; Pass(f) else Apply(f, kc) end
            end
        end
    end)
end

local function Hook(frame, kc)
    -- (A23 SD-12) a window that was let go (SetActive(false): the settings window's AceGUI frame, recycled for another addon) with its
    -- keyboard already off is not touched again
    frame:HookScript("OnShow", function(self) if kc.active or kc.kb then Apply(self, kc) end end)
    frame:HookScript("OnHide", function(self) if kc.active or kc.kb then Apply(self, kc) end end)
    frame:HookScript("OnKeyDown", function(self, key)
        if not kc.active then return end
        local fight = Fighting()
        local action = Binding(key)
        -- what happened to the last key (the QA walkthrough reads it through ns.KeyCatchList; one table per window, reused)
        local last = kc.last or {}
        kc.last = last
        last.key, last.fight, last.binding, last.used = key, fight, action, false
        if action == "SCREENSHOT" or NEVER_HOLD[key] then   -- the screenshot key is the game's, untouched (Blizzard's StaticPopup / CinematicFrame)
            if not fight then Pass(self) end
            return
        end
        -- in combat the flag rests at true (set before the lockdown) and cannot change: a key the game uses (or may use) is left to it
        -- alone, so it never does two things; the handler runs only for a key with no game binding
        if fight and action ~= false then return end
        local ok, used = xpcall(kc.handler, Report, self, key, fight)
        last.used = (ok and used == true) and true or false
        if fight then return end   -- restricted in combat: the flag stays at true (set before the lockdown)
        if ok and used == true then
            pcall(self.SetPropagateKeyboardInput, self, false)   -- this key only
            kc.held = true
            C_Timer.After(0, function()
                kc.held = nil
                if not Fighting() then Pass(self) end
            end)
        else
            Pass(self)
        end
    end)
end

function ns.KeyCatch(frame, handler)
    if not frame then return nil end
    local kc = catches[frame]
    if kc then kc.handler = handler; return kc end
    kc = { frame = frame, handler = handler, active = true }
    catches[frame] = kc
    function kc.SetActive(on)
        kc.active = on and true or false
        Apply(frame, kc)
    end
    WatchCombat()
    -- (review R1) a window first made in combat gets no OnKeyDown yet: an OnKeyDown script switches the frame's keyboard on
    -- (INFERENCE: AceGUI's Keybinding widget turns it off right after setting one), and in combat the pass-on flag cannot be set, so
    -- every key (movement, PRINTSCREEN) would stay with the window until the fight ends. Set up at PLAYER_REGEN_ENABLED instead.
    function kc.setup()
        if kc.ready then return end
        kc.ready = true
        Hook(frame, kc)
        Apply(frame, kc)
    end
    if not Fighting() then kc.setup() end
    return kc
end
-- (QA walkthrough and tests) every window that takes keys, with what the game reads from it
function ns.KeyCatchList()
    local out = {}
    for f, kc in pairs(catches) do
        local okN, name = pcall(f.GetName, f)
        local okP, prop = pcall(f.GetPropagateKeyboardInput, f)
        local pass = nil   -- (true / false as the game reports it; nil = could not be read)
        if okP and type(prop) == "boolean" then pass = prop end
        out[#out + 1] = { frame = f, name = okN and name or nil, active = kc.active, shown = f:IsShown() and true or false,
            keyboard = kc.kb, propagate = pass, held = kc.held, last = kc.last }
    end
    return out
end

local function TopOf(f)
    local p = f
    while p and p.GetParent do
        local up = p:GetParent()
        if not up or up == UIParent then return p end
        p = up
    end
    return p
end
local letGo   -- the last time a guarded box let go of the keyboard: { how = "enter" / "escape" / "click" / "hide" / "combat", t, win } (QA walkthrough)
local function Note(box, how)
    local o = guarded[box]
    letGo = letGo or {}
    letGo.how, letGo.t, letGo.win = how, GetTime and GetTime() or 0, o and o.win or nil
end
function ns.KeyFocusLastLetGo() return letGo end
local function Done(box, how)
    Note(box, how)
    box:ClearFocus()
    local o = guarded[box]
    if o and o.onDone then local ok, e = pcall(o.onDone, box); if not ok then Report(e) end end
end
-- (review R23) a fight starting lets go too: a box left with the keyboard (several take it when they open) would get her movement and
-- keybinds. PLAYER_REGEN_DISABLED, and ADDON_RESTRICTION_STATE_CHANGED (events.md 37: type, state) when an encounter, a Mythic+ run
-- or a PvP match restricts addons (Enum.AddOnRestrictionType Combat 0 / Encounter 1 / ChallengeMode 2 / PvPMatch 3; state
-- Activating 1 / Active 2; enums.md 485-504). ClearFocus is not a protected function (widgets.md), so it may run in combat.
local FIGHT_TYPE = { [0] = true, [1] = true, [2] = true, [3] = true }
local WATCHED = { "GLOBAL_MOUSE_DOWN", "PLAYER_REGEN_DISABLED", "ADDON_RESTRICTION_STATE_CHANGED" }
local listening = false
-- (A23 SD-12) the watcher's events, on only while a guarded box has the keyboard
local function Listen(on)
    if on == listening or not mouseWatch then return end
    listening = on
    for _, ev in ipairs(WATCHED) do if on then mouseWatch:RegisterEvent(ev) else mouseWatch:UnregisterEvent(ev) end end
end
local function AnyFocus(except)
    for box in pairs(guarded) do if box ~= except and box:HasFocus() then return true end end
    return false
end
local function WatchMouse()
    if mouseWatch then return end
    mouseWatch = CreateFrame("Frame")
    -- (a click: one pass over the guarded boxes, HasFocus each: about 30 own boxes plus the settings window's open page; only while
    -- one of them has the keyboard)
    mouseWatch:SetScript("OnEvent", function(_, ev, kind, state)
        local fight = ev == "PLAYER_REGEN_DISABLED"
        if ev == "ADDON_RESTRICTION_STATE_CHANGED" then
            if not (FIGHT_TYPE[kind] and (state == 1 or state == 2)) then return end
            fight = true
        end
        for box, o in pairs(guarded) do
            if box:HasFocus() then
                if fight then Done(box, "combat")
                else
                    local keep = o.within or box
                    if not (keep.IsMouseOver and keep:IsMouseOver()) then Done(box, "click") end
                end
            end
        end
        if not AnyFocus() then Listen(false) end   -- (also when a box lost the keyboard without its OnEditFocusLost being seen)
    end)
end
local function FocusGained(self) if guarded[self] then Listen(true) end end
local function FocusLost(self) if guarded[self] and not AnyFocus(self) then Listen(false) end end

local hookedBox = setmetatable({}, { __mode = "k" })   -- edit box -> its hooks are in (HookScript cannot be undone: they check guarded[])
local enterHooked = setmetatable({}, { __mode = "k" })
local function DoneEnter(self) Done(self, "enter") end
local function DoneEscape(self) Done(self, "escape") end
local function LetGoAfterEnter(self) local o = guarded[self]; if o and o.enterLetsGo and self:HasFocus() then Done(self, "enter") end end
function ns.KeyFocusGuard(box, opts)
    if not box or guarded[box] then return box end
    opts = opts or {}
    guarded[box] = opts
    if box.SetAutoFocus then box:SetAutoFocus(false) end
    if not box:GetScript("OnEscapePressed") then box:SetScript("OnEscapePressed", DoneEscape) end
    local multi = box.IsMultiLine and box:IsMultiLine()
    if not multi and not box:GetScript("OnEnterPressed") then box:SetScript("OnEnterPressed", DoneEnter)
    elseif not multi and opts.enterLetsGo and not enterHooked[box] then enterHooked[box] = true; box:HookScript("OnEnterPressed", LetGoAfterEnter) end   -- after the box's own Enter
    if not hookedBox[box] then
        hookedBox[box] = true
        box:HookScript("OnHide", function(self) if guarded[self] and self:HasFocus() then Note(self, "hide"); self:ClearFocus() end end)
        box:HookScript("OnEditFocusGained", FocusGained)
        box:HookScript("OnEditFocusLost", FocusLost)
    end
    local win = opts.window or TopOf(box)
    opts.win = win
    if win and win ~= box and not windowHooked[win] then
        windowHooked[win] = true
        win:HookScript("OnHide", function(w)
            for b, o in pairs(guarded) do if o.win == w and b:HasFocus() then Note(b, "hide"); b:ClearFocus() end end
        end)
    end
    WatchMouse()
    if box:HasFocus() then Listen(true) end   -- (it had the keyboard before it was guarded)
    return box
end
-- a box handed back (an AceGUI widget released for another addon): XayaUI stops acting on it; its hooks stay but do nothing
function ns.KeyFocusRelease(box)
    if box then guarded[box] = nil end
    if listening and not AnyFocus() then Listen(false) end
end
