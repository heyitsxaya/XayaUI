-------------------------------------------------------------------------------
-- QAWalks-debug.lua (XayaUI Dev Assist 0.7.5): the in-game QA walkthroughs for the debug-tools round (REQUEST-LOG #81, #82; QA-CHECKLIST
-- B180-B183, D14, E1z90, F19), written for the shared walkthrough framework (XayaUI_DevAssist/QAWalk.lua, `/xui dev qa`, standing rule
-- V20) that another branch is building. That framework is not on main yet, so this file is NOT in XayaUI_DevAssist.toc: the game never
-- reads it until the framework lands and the file is added to the toc after QAWalks.lua. Even then it does nothing without the framework.
-- Each check reads only what the addon itself sees (its lists and settings); what only a person can see (a tooltip line, a window's
-- look) stays a manual step with its text.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end
local ns = rawget(_G, "XayaUI_NS")
if type(ns) ~= "table" then return end

local function debugNames()
    local out = ns.CaptureOutput(function() SlashCmdList.XAYAUI("debug") end)
    local names = {}
    for _, l in ipairs(out) do
        local n = tostring(l):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^  /xui debug (%S+)")
        if n then names[n] = true end
    end
    return names
end

QA.Register("debug-tools-devassist", { title = "Developer tools are XayaUI Dev Assist's", qa = "B181", order = 181, steps = {
    { text = "With Dev Assist on, /xui debug lists the developer commands as well as the player's.",
      check = function()
          local names, miss = debugNames(), {}
          for _, n in ipairs({ "probe", "timing", "model", "tracker", "mods", "groups", "icons", "media", "seed", "map", "debuffs", "loc",
              "gamemenu", "chatprobe", "widthprobe", "status", "perf", "talents", "loader", "auras" }) do
              if not names[n] then miss[#miss + 1] = n end
          end
          return #miss == 0, #miss == 0 and "every command listed" or ("missing: " .. table.concat(miss, ", "))
      end },
    { text = "/xuitt exists, and /xuiskin pad, /xuiengine auto and /xui chat wrap are registered.",
      check = function()
          local ok = type(SlashCmdList.XUITT) == "function" and #ns.SubcommandHelp("xuiskin") == 2 and #ns.SubcommandHelp("xuiengine") == 3
              and #ns.SubcommandHelp("chat") == 3
          return ok, ("xuitt %s; xuiskin %d, xuiengine %d, chat %d words"):format(tostring(type(SlashCmdList.XUITT) == "function"),
              #ns.SubcommandHelp("xuiskin"), #ns.SubcommandHelp("xuiengine"), #ns.SubcommandHelp("chat"))
      end },
    { text = "Hover Fiery Brand (Aura IDs on): each Aura ID line ends in grey with \"via ...\" (QA F19). The addon side: the tooltip's source text is on.",
      check = function()
          local t = ns.TT and ns.TT.SourceText and ns.TT.SourceText({ src = { ["your casts"] = true } }) or ""
          return t:find("via", 1, true) ~= nil, t ~= "" and "source text on" or "source text off (is XayaUI Bonus Features on?)"
      end },
} })

QA.Register("debug-report", { title = "Debug report: codes, summary and string", qa = "B182", order = 182, steps = {
    { text = "Advanced Debugging is on (the default).",
      check = function() return ns.AdvancedDebugOn() == true, "Advanced Debugging " .. (ns.AdvancedDebugOn() and "on" or "OFF") end },
    { text = "A test error raised in a XayaUI file is recorded as XUI-E001; one from elsewhere is not.",
      setup = function()
          local f = loadstring("error('QA walkthrough test error')", "@Interface/AddOns/XayaUI/QAWalk.lua")
          if f then xpcall(f, function(e) local h = geterrorhandler(); if h then pcall(h, e) end end) end
          local g = loadstring("error('QA walkthrough, not XayaUI')", "@Interface/AddOns/NotXayaUI/QAWalk.lua")
          if g then xpcall(g, function(e) local h = geterrorhandler(); if h then pcall(h, e) end end) end
      end,
      check = function()
          local mine, other = nil, false
          for _, e in ipairs(ns.ErrorEntries()) do
              if e.msg:find("QA walkthrough test error", 1, true) then mine = e end
              if e.msg:find("not XayaUI", 1, true) then other = true end
          end
          return mine ~= nil and mine.code == "XUI-E001" and not other,
              (mine and ("recorded as " .. tostring(mine.code) .. " x" .. tostring(mine.n)) or "not recorded") .. (other and "; the other one was recorded too" or "")
      end },
    { text = "/xui report: the window shows the entry with its meaning, and a string; screenshot it.",
      setup = function() if ns.ShowDebugReport then ns.ShowDebugReport() end end,
      check = function()
          local w = ns.DebugReportWindow and ns.DebugReportWindow()
          local text, str = w and w.text:GetText() or "", w and w.str:GetText() or ""
          return text:find("XUI-E001", 1, true) ~= nil and str:find("^XUIREP1:") ~= nil, ("summary %s; string %d characters"):format(
              text:find("XUI-E001", 1, true) and "names XUI-E001" or "has no XUI-E001", #str)
      end },
} })
