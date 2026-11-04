-------------------------------------------------------------------------------
-- StatMath.lua : the arithmetic behind QoL > Character Stats (XayaUI QoL 0.6.2). No frames and no game calls here: every function
-- takes the game's own rating converter as an argument, f(rating) -> percent, so it can be tested offline with a stand-in.
--
-- Why a converter and not a table: XayaUI never ships stat tables from outside the game (#290). The game exposes
-- GetCombatRatingBonusForCombatRatingValue(ratingIndex, value), which answers "what percent would this much rating give". Everything
-- below is read from that answer:
--   base rate        percent per rating point where no penalty applies (measured at a small rating)
--   thresholds       ratings where the percent gained per point drops (diminishing returns), found by scanning the converter
--   lost rating      rating that buys nothing because of the penalty: rating - (percent now / base rate)
--   next 1%          the exact extra rating for one more percent, found by bisection on the converter (crosses thresholds correctly)
-- If the converter shows no penalty anywhere, no thresholds are reported. Whether the live converter applies diminishing returns is
-- NOT CONFIRMED IN GAME (#325); CharacterStats.lua compares it with the game's current value and says so when they disagree.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns

local M = {}
ns.StatMath = M

local SMALL = 10            -- rating used to measure the no-penalty rate (well below any threshold)
local TOL = 0.02            -- a change of 2% in the gain per point counts as a new bracket (real brackets differ by 10%;
                            -- the margin absorbs a converter that rounds its answer to 0.01%)

local function num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end

-- percent per rating point with no penalty; nil when the converter gives nothing usable. A first guess from a small rating, then
-- re-measured over about 5% (then 2%, 1%) so a converter that rounds its answer does not skew it; a wider reading is only used when
-- the curve is still straight there (its half-way point agrees), so a stat whose first threshold is low is still read correctly.
function M.BaseRate(f)
    local function F(x) local ok, v = pcall(f, x); if ok and num(v) then return v end end
    local v = F(SMALL)
    if not v or v <= 0 then return nil end
    local guess = v / SMALL
    for _, pct in ipairs({ 5, 2, 1 }) do
        local X = math.floor(pct / guess)
        if X > 2 * SMALL then
            local a, b = F(math.floor(X / 2)), F(X)
            if a and b and b > 0 then
                local ra, rb = a / math.floor(X / 2), b / X
                if math.abs(ra - rb) <= 0.005 * rb then return rb end
            end
        end
    end
    return guess
end

-- Thresholds of f up to maxPct percent (before penalties). Returns a list of { rating, pct, penalty } where penalty is the share of
-- each further point that is lost (0.1 = 10%), plus a flag when the curve changes too often to be read as brackets.
function M.Thresholds(f, r0, maxPct)
    local out = {}
    if not num(r0) or r0 <= 0 then return out end
    local xmax = math.floor((maxPct or 200) / r0)
    if xmax < 2 then return out end
    local step = math.max(1, math.floor(xmax / 300))
    local function F(x) local ok, v = pcall(f, x); if ok and num(v) then return v end end

    local segStart, segPct, segPen = 0, F(0) or 0, 0
    local x, fx = 0, F(0) or 0
    while x < xmax do
        local nx = x + step
        local fn = F(nx)
        if not fn then break end
        local pen = 1 - (fn - fx) / (step * r0)
        if math.abs(pen - segPen) > TOL then
            -- the bracket changed somewhere in (x, nx]. Measure the new slope over a wider window after nx (about 2% of rating,
            -- so a converter that rounds to 0.01% cannot fake a change), then intersect the old and new straight lines: exact for an
            -- exact converter, within a few points for a rounded one.
            local W = math.max(step, math.ceil(2 / r0))
            local fW = F(nx + W)
            local m2 = fW and (fW - fn) / W
            local pen2 = m2 and (1 - m2 / r0)
            if pen2 and math.abs(pen2 - segPen) > TOL then
                -- the old line is fitted just before the change too, not run all the way from the last threshold: a tiny error in
                -- the slope would otherwise grow over a thousand points of rating
                local rate, a2 = (1 - segPen) * r0, math.max(segStart, x - step)
                local a1 = math.max(segStart, a2 - W)
                local fa1, fa2 = F(a1), F(a2)
                local anchor = segPct + rate * (a2 - segStart)
                if fa1 and fa2 and a2 - a1 >= 2 then rate, anchor = (fa2 - fa1) / (a2 - a1), fa2 end
                local T = a2 + (fn - m2 * (nx - a2) - anchor) / (rate - m2)
                T = math.floor(T + 0.5)
                if T <= segStart then T = segStart + 1 elseif T > nx then T = nx end
                local after = math.floor(pen2 * 100 + 0.5) / 100   -- brackets are whole percents; drop rounding noise
                if after < 0 then after = 0 elseif after > 1 then after = 1 end
                local pctT = anchor + rate * (T - a2)
                out[#out + 1] = { rating = T, pct = pctT, penalty = after }
                if #out >= 12 then out.smooth = true; break end
                -- the new line starts at the threshold; the scan always moves on by a whole step, so it cannot loop
                -- (two thresholds inside one window, about 2% of rating, would be read as one)
                segStart, segPct, segPen = T, pctT, after
            end
            x, fx = nx, fn
        else
            x, fx = nx, fn
        end
    end
    return out
end

-- Smallest extra rating d (whole points) such that f(x + d) - f(x) >= gain. nil when no amount up to maxX reaches it (capped).
function M.RatingForGain(f, x, gain, maxX)
    if not num(gain) or gain <= 0 then return nil end
    local function F(v) local ok, r = pcall(f, v); if ok and num(r) then return r end end
    local f0 = F(x)
    if not f0 then return nil end
    maxX = maxX or 1e6
    local hi = 1
    while true do
        local fh = F(x + hi)
        if not fh then return nil end
        if fh - f0 >= gain - 1e-9 then break end
        if hi >= maxX then return nil end
        hi = math.min(maxX, hi * 2)
    end
    local lo = 0
    while hi - lo > 1 do
        local mid = math.floor((lo + hi) / 2)
        local fm = F(x + mid)
        if fm and fm - f0 >= gain - 1e-9 then hi = mid else lo = mid end
    end
    return hi
end

-- Everything the panel shows for one rating. coeff turns converter percent into the stat's own percent (mastery: the spec's
-- mastery factor; everything else: 1). pctNow is the game's own current value from rating, when it can be read.
function M.Analyze(f, rating, r0, thresholds, coeff, pctNow)
    coeff = (num(coeff) and coeff > 0) and coeff or 1
    local a = { rating = rating, base = r0, coeff = coeff }
    if not num(rating) or not num(r0) or r0 <= 0 then return a end
    local ok, conv = pcall(f, rating)
    a.conv = (ok and num(conv)) and conv or nil
    a.pct = (num(pctNow) and pctNow) or a.conv
    if a.conv and num(pctNow) then
        a.mismatch = math.abs(a.conv - pctNow) > math.max(0.05, 0.01 * math.abs(pctNow))
    end
    if a.pct then
        a.effective = a.pct / r0
        a.lost = math.max(0, rating - a.effective)
        if a.lost < 0.5 then a.lost = 0 end
    end
    -- the penalty now: the bracket of the last threshold passed (exact); without thresholds, measured over about 2% of rating
    local pen
    if thresholds then
        pen = 0
        for _, t in ipairs(thresholds) do if rating >= t.rating then pen = t.penalty end end
    else
        local H = math.max(10, math.ceil(2 / r0))
        local ok1, f1 = pcall(f, rating)
        local ok2, f2 = pcall(f, rating + H)
        if ok1 and ok2 and num(f1) and num(f2) then pen = 1 - (f2 - f1) / (H * r0) end
    end
    if pen then
        if pen < 0.005 then pen = 0 elseif pen > 1 then pen = 1 end
        a.penalty = pen
        local m = (1 - pen) * r0
        a.marginal = m
        a.perPctNow = m > 1e-9 and 1 / (m * coeff) or nil
    end
    a.perPctBase = 1 / (r0 * coeff)
    a.nextOne = M.RatingForGain(f, rating, 1 / coeff)
    for _, t in ipairs(thresholds or {}) do
        if t.rating > rating then a.nextThreshold = t; a.toNext = t.rating - rating; break end
    end
    return a
end

-- Inverse of a monotone function g on [lo, hi]: the x where g(x) = target (bisection, 40 steps). Used for armor and the GCD.
function M.Solve(g, target, lo, hi, increasing)
    local function G(x) local ok, v = pcall(g, x); if ok and num(v) then return v end end
    local glo, ghi = G(lo), G(hi)
    if not glo or not ghi then return nil end
    if increasing == nil then increasing = ghi >= glo end
    if increasing and (target < glo or target > ghi) then return nil end
    if not increasing and (target > glo or target < ghi) then return nil end
    for _ = 1, 40 do
        local mid = (lo + hi) / 2
        local gm = G(mid)
        if not gm then return nil end
        if (gm < target) == increasing then lo = mid else hi = mid end
    end
    return (lo + hi) / 2
end

return M
