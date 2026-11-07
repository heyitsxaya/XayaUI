local fails, n = 0, 0
local function check(name, ok) n = n + 1; if not ok then fails = fails + 1; print("FAIL: " .. name) end end
local function load_blocks(env)
    -- a private LibStub per environment, so each check gets a fresh copy of the library (0.6.0: Data Blocks is a LibStub library)
    assert(load(LIBSTUB_SRC, "@LibStub.lua", "t", env))()
    local chunk = assert(load(DATA_SRC, "@XayaDataBlocks-1.0.lua", "t", env))
    chunk("XayaUI_Chat", {})
    return env.LibStub("XayaDataBlocks-1.0")
end
local function mkenv(extra)
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.GetTime = function() return 100 end
    env.Enum = { AddOnProfilerMetric = { SessionAverageTime = 0, RecentAverageTime = 1, PeakTime = 4 } }
    for k, v in pairs(extra or {}) do env[k] = v end
    return env
end
local mem = { 500, 20480, 0, 90 }
local names = { "Alpha", "Beta", "Gamma", "Delta" }
local updates = 0
local app = { [0] = 100, [1] = 100, [4] = 200 }
local over = { [0] = 7, [1] = 3, [4] = 54 }
local per = { Alpha = { [0] = 1, [1] = 2 }, Beta = { [0] = 5, [1] = 1 } }
local prof = {
    IsEnabled = function() return true end,
    GetApplicationMetric = function(m) return app[m] end,
    GetOverallMetric = function(m) return over[m] end,
    GetAddOnMetric = function(n, m) return per[n][m] end,
    GetTopKAddOnsForMetric = function(m, k) return { { addOnName = "Alpha" }, { addOnName = "Beta" } } end,
}
local env = mkenv({ C_AddOnProfiler = prof,
    UpdateAddOnMemoryUsage = function() updates = updates + 1 end,
    GetAddOnMemoryUsage = function(i) return mem[i] end,
    C_AddOns = { GetNumAddOns = function() return 4 end, GetAddOnInfo = function(i) return names[i] end } })
local B = load_blocks(env)
local lines = B.UsageLines(8)
local text = table.concat(lines, "\n")
check("heading", lines[1] == "#AddOn usage")
check("overall cpu shows 3% now / 7% avg / 27% peak", text:find("CPU now: 3%%    average: 7%%    peak: 27%%") ~= nil)
check("top cpu has Alpha", text:find("Alpha") ~= nil and text:find("Top by CPU") ~= nil)
check("memory total in MB", text:find("Memory: 20.6 MB total") ~= nil)
check("memory sorted, Beta first (20.0 MB)", text:find("20.0 MB   Beta") ~= nil)
check("zero-memory addon left out", text:find("Gamma") == nil)
check("small values in KB", text:find("90 KB   Delta") ~= nil)
B.UsageLines(8)
check("memory not re-read by a redraw", updates == 1)
-- profiler missing
local B2 = load_blocks(mkenv({}))
local t2 = table.concat(B2.UsageLines(5), "\n")
check("no profiler: message, no error", t2:find("not available") ~= nil)
-- secret values are skipped, never compared
local env3 = mkenv({ C_AddOnProfiler = prof, issecretvalue = function(v) return v == 20480 end,
    UpdateAddOnMemoryUsage = function() end, GetAddOnMemoryUsage = function(i) return mem[i] end,
    C_AddOns = { GetNumAddOns = function() return 4 end, GetAddOnInfo = function(i) return names[i] end } })
local B3 = load_blocks(env3)
local t3 = table.concat(B3.UsageLines(8), "\n")
check("secret memory value skipped", t3:find("Beta") == nil or t3:find("MB   Beta") == nil)
-- API that throws does not break the tooltip
local env4 = mkenv({ C_AddOnProfiler = { IsEnabled = function() error("boom") end } })
local ok = pcall(function() load_blocks(env4).UsageLines(8) end)
check("throwing API contained", ok)
-- AddUsage heading colors
local added = {}
local tip = { AddLine = function(_, s, r, g, b) added[#added + 1] = { s, r, g, b } end }
B.AddUsage(tip, 3)
check("AddUsage: blank line first, gold headings", added[1][1] == " " and added[2][1] == "AddOn usage" and added[2][3] == 0.82)
check("AddUsage: ends with the grey cost line (MINOR 2)", added[#added][1] == "Includes the cost of reading these numbers." and added[#added][2] == 0.6)
-- MINOR 2 (REQUEST-LOG A15 P-14): memory is read once per hover (readMemory), never on the once-a-second redraws
do
    local now, ups = 100, 0
    local env5 = mkenv({ C_AddOnProfiler = prof, GetTime = function() return now end,
        UpdateAddOnMemoryUsage = function() ups = ups + 1 end, GetAddOnMemoryUsage = function(i) return mem[i] end,
        C_AddOns = { GetNumAddOns = function() return 4 end, GetAddOnInfo = function(i) return names[i] end } })
    local B5 = load_blocks(env5)
    B5.UsageLines(8, true)                                   -- the hover's first show
    for s = 1, 40 do now = now + 1; B5.UsageLines(8) end      -- 40 s of redraws while hovered
    check("hovered 40 s: memory read once (at the first show), not every 15 s (" .. ups .. ")", ups == 1)
    now = now + 5; B5.UsageLines(8, true)                    -- a new hover later
    check("a new hover reads memory again", ups == 2)
    B5.UsageLines(8, true)                                   -- re-entered within a second
    check("re-entering within a second reuses the reading", ups == 2)
end
print(string.format("%d checks, %d failed", n, fails))
if fails > 0 then error("failed") end
