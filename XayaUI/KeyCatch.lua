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
--     called in combat); the result's SetActive(false) lets go of the keyboard (a recycled AceGUI window that another addon gets).
-- ns.KeyFocusGuard(editBox, opts): a text box never keeps the keyboard after the player is done with it:
--   * no focus on show (SetAutoFocus(false)); Escape clears the focus (a box's own Escape script is kept); Enter clears it in a
--     one-line box that has no Enter script of its own;
--   * a mouse click outside opts.within (default: the box) clears it (GLOBAL_MOUSE_DOWN);
--   * the box or its window (opts.window, default: its top frame under UIParent) hiding clears it (the game also drops the focus of a
--     hidden box, Options' Skin.lua search box notes; cleared here as well, so it never depends on that);
--   * opts.onDone(box) runs after Enter / Escape / a click outside cleared it.
-- V14: nothing is made until the first window or box asks for it (the event frames are created then).
-------------------------------------------------------------------------------
local _, ns = ...

local NEVER_HOLD = { PRINTSCREEN = true }
local catches = setmetatable({}, { __mode = "k" })   -- frame -> its state
local guarded = setmetatable({}, { __mode = "k" })   -- edit box -> its options
local windowHooked = setmetatable({}, { __mode = "k" })
local combatWatch, mouseWatch

local function Fighting() return InCombatLockdown and InCombatLockdown() and true or false end
local function Report(e) local h = geterrorhandler and geterrorhandler(); if h then pcall(h, e) end end
-- the resting state: every key goes on to the game
local function Pass(f)
    if f.SetPropagateKeyboardInput then pcall(f.SetPropagateKeyboardInput, f, true) end
end
-- out of combat only: keyboard on while active and shown, the flag at rest either way
local function Apply(f, kc)
    if Fighting() then return end
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
            -- before the lockdown begins: the flag goes back to true, so no key is kept from the game in the fight
            if ev == "PLAYER_REGEN_DISABLED" then kc.held = nil; Pass(f) else Apply(f, kc) end
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
    frame:HookScript("OnShow", function(self) Apply(self, kc) end)
    frame:HookScript("OnHide", function(self) Apply(self, kc) end)
    frame:HookScript("OnKeyDown", function(self, key)
        if not kc.active then return end
        local fight = Fighting()
        local ok, used = xpcall(kc.handler, Report, self, key, fight)
        if fight then return end   -- restricted in combat: the flag stays at true (set before the lockdown)
        if ok and used == true and not NEVER_HOLD[key] then
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
    WatchCombat()
    Apply(frame, kc)
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
            keyboard = kc.kb, propagate = pass, held = kc.held }
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
local function Done(box)
    box:ClearFocus()
    local o = guarded[box]
    if o and o.onDone then local ok, e = pcall(o.onDone, box); if not ok then Report(e) end end
end
local function WatchMouse()
    if mouseWatch then return end
    mouseWatch = CreateFrame("Frame")
    mouseWatch:RegisterEvent("GLOBAL_MOUSE_DOWN")
    mouseWatch:SetScript("OnEvent", function()
        for box, o in pairs(guarded) do
            if box:HasFocus() then
                local keep = o.within or box
                if not (keep.IsMouseOver and keep:IsMouseOver()) then Done(box) end
            end
        end
    end)
end

function ns.KeyFocusGuard(box, opts)
    if not box or guarded[box] then return box end
    opts = opts or {}
    guarded[box] = opts
    if box.SetAutoFocus then box:SetAutoFocus(false) end
    if not box:GetScript("OnEscapePressed") then box:SetScript("OnEscapePressed", Done) end
    if not (box.IsMultiLine and box:IsMultiLine()) and not box:GetScript("OnEnterPressed") then box:SetScript("OnEnterPressed", Done) end
    box:HookScript("OnHide", function(self) if self:HasFocus() then self:ClearFocus() end end)
    local win = opts.window or TopOf(box)
    opts.win = win
    if win and win ~= box and not windowHooked[win] then
        windowHooked[win] = true
        win:HookScript("OnHide", function(w)
            for b, o in pairs(guarded) do if o.win == w and b:HasFocus() then b:ClearFocus() end end
        end)
    end
    WatchMouse()
    return box
end
