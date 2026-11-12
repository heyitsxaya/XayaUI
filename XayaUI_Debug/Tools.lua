-------------------------------------------------------------------------------
-- XayaUI Debug: XayaUI's debug tools in their own load-on-demand addon (bundle 1 round 7). REQUEST-LOG A23 SD-58, her answer on the
-- debug tools: "1 but nothing loads unless "Debugging" is enabled"; SD-61, the Debugging default: "Off by default (Recommended)";
-- SD-64: a saved "on" is kept, and every login or /reload while it is on prints one chat line; V34: "if the addon or element within an
-- addon is off it should not be read at all ... and should be detected once per reload".
--
-- How it loads: XayaUI core (XayaUI/DebugRecord.lua) loads this addon once per login or /reload, at the login, only while Settings >
-- Debugging > Advanced Debugging (CueRulesDB.ui.advancedDebug) is on. Nothing else loads it, so with Advanced Debugging off none of
-- these files is read. Turned on during a session it loads at the next /reload; turned off, it stays until the next /reload (the game
-- cannot unload code).
-- What stays in core either way: catching and recording XayaUI's own errors (Core.lua's error handler, DebugRecord.lua), the log buffer
-- (ns.logBuf) and the console's line feed with its private queue (ns.ConsoleSink, Console.lua), so the console window catches up on
-- every line that came before it was built.
-- How a debug piece plugs in: its file is appended to XayaUI_Debug.toc and registers its words through Modules.lua (ns.RegisterDebugCommand
-- for /xui debug <name>, ns.RegisterCommand for /xui <name>). While this addon is not loaded, core answers every debug word but its own
-- loader and talents (Core.lua DEBUG_UNGATED) with one plain line saying it needs Advanced Debugging and a /reload (ns.DebugToolsNeeded).
-- V26 (combat lock): every tool here is exempt (her words: "unless flagged for exemption (e.g. debugging)"; the error / bug report, the
-- console window and read-only /xui debug commands): each works in combat.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (## Dependencies: XayaUI)

-- core's debug words now run here (DebugRecord.lua ns.DebugToolsLoaded)
if ns.DebugToolsArrived then ns.DebugToolsArrived() end
