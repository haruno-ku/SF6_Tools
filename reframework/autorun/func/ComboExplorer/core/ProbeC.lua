-- =========================================================
-- ComboExplorer/core/ProbeC.lua - measures what a stage reset costs, by
-- watching the operator do it. Pure: takes per-tick observations.
-- =========================================================
--
-- WHAT THIS ANSWERS
--
-- Two things, and neither needs a single button to be pressed:
--
--   * How long a training-stage reset actually takes. Provenance holds
--     reset_settle_ticks at an unverified 25, arrived at by adding two of
--     upstream's own numbers together; the refresh itself is unbounded, and
--     upstream polls for it rather than predicting it.
--   * What one attempt will cost in real time. That single number decides how
--     large the brute-force matrix can be, and there is no way to run the game
--     faster - a repo-wide search for TimeScale or frame-skip finds nothing.
--
-- Both are measurable by watching: the operator resets from the training menu a
-- dozen times, and the probe times the episodes.
--
-- A RESET IS NOT AN INSTANT
--
-- TrainingManager._IsReqRefresh is a request. Upstream raises it, polls until
-- it clears, then applies an exact position correction with a retry budget, and
-- separately refuses to believe the combo counter for another fifteen frames.
-- So the interesting quantity is not "how long was the flag up" but "how long
-- until the stage was actually reproducible", and the probe measures both.

local M = { name = "ComboExplorer.ProbeC" }

local Probe = {}
Probe.__index = Probe
M.Probe = Probe

-- The settle condition, deliberately conservative and stated in one place:
-- both players idle, no combo counter running, and position stable across a
-- few ticks. Nothing here is a measured constant - the point is to measure how
-- long it takes to become true.
local DEFAULT_STABLE_TICKS = 5
local DEFAULT_POS_TOLERANCE = 0.01

function M.new(opts)
    opts = opts or {}
    local p = setmetatable({}, Probe)
    p.stable_ticks = opts.stable_ticks or DEFAULT_STABLE_TICKS
    p.pos_tolerance = opts.pos_tolerance or DEFAULT_POS_TOLERANCE
    p:reset()
    return p
end

function Probe:reset()
    self.episodes = {}
    self.state = "idle"
    self.open = nil
    self.ticks = 0
    self.last_refreshing = false
    self.stable_run = 0
    self.last_pos = nil
end

-- obs:
--   refreshing   : TrainingManager._IsReqRefresh
--   combo_count  : attacker combo counter
--   attacker_act_st / victim_act_st : action states (0 is idle)
--   attacker_pos / victim_pos : positions, for the stability test
--   wall_clock   : os.clock() at this tick, optional but what makes the
--                  wall-time answer possible
function Probe:tick(obs, tick_index)
    if type(obs) ~= "table" then return nil end
    self.ticks = self.ticks + 1

    local refreshing = obs.refreshing == true

    -- Rising edge: a reset has been requested.
    if refreshing and not self.last_refreshing then
        self.open = {
            start_tick = tick_index,
            start_wall = obs.wall_clock,
            refresh_ticks = 0,
        }
        self.state = "refreshing"
        self.stable_run = 0
        self.last_pos = nil
    end

    if self.open and self.state == "refreshing" then
        -- Only while the flag is actually up. Counting the tick on which it
        -- cleared would report every refresh as one tick longer than it was,
        -- and this number goes on to size the whole brute-force matrix.
        if refreshing then
            self.open.refresh_ticks = self.open.refresh_ticks + 1
        end
        if not refreshing then
            -- Falling edge: the flag cleared. The stage is NOT yet
            -- reproducible - that is the next thing being timed.
            self.open.refresh_cleared_tick = tick_index
            self.open.refresh_cleared_wall = obs.wall_clock
            self.state = "settling"
            self.open.settle_ticks = 0
        end
    elseif self.open and self.state == "settling" then
        self.open.settle_ticks = self.open.settle_ticks + 1

        local idle = (obs.attacker_act_st == 0) and (obs.victim_act_st == 0)
        local no_combo = ((obs.combo_count or 0) == 0)

        local pos_stable = false
        if obs.attacker_pos ~= nil and obs.victim_pos ~= nil then
            local d = math.abs(obs.attacker_pos - obs.victim_pos)
            if self.last_pos ~= nil and math.abs(d - self.last_pos) <= self.pos_tolerance then
                pos_stable = true
            end
            self.last_pos = d
        end

        if idle and no_combo and pos_stable then
            self.stable_run = self.stable_run + 1
        else
            self.stable_run = 0
        end

        if self.stable_run >= self.stable_ticks then
            local e = self.open
            e.settled_tick = tick_index
            e.settled_wall = obs.wall_clock
            e.total_ticks = tick_index - e.start_tick
            if e.start_wall and e.settled_wall then
                e.total_wall_ms = (e.settled_wall - e.start_wall) * 1000
            end
            e.final_distance = self.last_pos
            self.episodes[#self.episodes + 1] = e
            self.open = nil
            self.state = "idle"
            self.stable_run = 0
            return e
        end
    end

    self.last_refreshing = refreshing
    return nil
end

local function stats(values)
    if #values == 0 then return nil end
    local lo, hi, sum = values[1], values[1], 0
    for _, v in ipairs(values) do
        if v < lo then lo = v end
        if v > hi then hi = v end
        sum = sum + v
    end
    table.sort(values)
    local mid = values[math.ceil(#values / 2)]
    return { min = lo, max = hi, mean = sum / #values, median = mid, n = #values }
end

-- What the episodes say a reset costs, and therefore what one attempt costs.
function M.conclude(episodes, opts)
    opts = opts or {}
    local min_episodes = opts.min_episodes or 5

    local total, refresh, settle, wall = {}, {}, {}, {}
    for _, e in ipairs(episodes or {}) do
        total[#total + 1] = e.total_ticks
        refresh[#refresh + 1] = e.refresh_ticks
        settle[#settle + 1] = e.settle_ticks
        if e.total_wall_ms then wall[#wall + 1] = e.total_wall_ms end
    end

    local out = {
        episodes = #episodes,
        total_ticks = stats(total),
        refresh_ticks = stats(refresh),
        settle_ticks = stats(settle),
        wall_ms = stats(wall),
        sufficient = (#episodes >= min_episodes),
    }

    if #episodes == 0 then
        out.verdict = "no resets observed - reset from the training menu a dozen times "
            .. "with the probe running"
        return out
    end
    if not out.sufficient then
        out.verdict = ("only %d resets observed - want %d before this is worth acting on")
            :format(#episodes, min_episodes)
        return out
    end

    -- The number the matrix size is decided from. Stated with its spread,
    -- because a mean alone hides a refresh that occasionally takes four times
    -- as long.
    local t = out.total_ticks
    out.verdict = ("a reset settles in %d-%d ticks (median %d)")
        :format(t.min, t.max, t.median)
    if out.wall_ms then
        out.verdict = out.verdict .. (", %.0f-%.0f ms wall clock (median %.0f)")
            :format(out.wall_ms.min, out.wall_ms.max, out.wall_ms.median)
    end

    -- A suggestion for Provenance.reset_settle_ticks: the worst case seen, not
    -- the average. A settle gate that is right on average is wrong half the
    -- time, and being wrong means starting a trial against a stale counter.
    out.suggested_settle_ticks = t.max
    out.suggested_note = "the maximum observed, not the mean - a gate that is right "
        .. "on average starts half its trials too early"

    return out
end

return M
