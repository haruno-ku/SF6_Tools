-- =========================================================
-- ComboExplorer/core/Scoring.lua - orders route candidates using only what can
-- be known without the game. Pure: a route in, an offline_score out.
-- =========================================================
--
-- WHAT THIS MAY AND MAY NOT USE
--
-- Only things that are either structural (how many inputs, how long the motion,
-- how many times the input method changes) or read straight out of the frame
-- source (damage, drive gain, super gain). Nothing here measures anything.
--
-- Three numbers are specifically NOT produced, and their absence is the point:
--
--   actual damage              - combo scaling is not in any frame table, and
--                                Modern's own damage reduction is in none of
--                                them either. The sum below is an upper bound
--                                for ordering, not a damage figure.
--   execution leniency         - how many frames wide the window is can only be
--                                measured by sweeping it on the real game.
--   knockdown advantage        - a large on-hit number may be oki advantage
--                                rather than link advantage, and no property in
--                                the source distinguishes them.
--
-- DIFFICULTY IS NOT COMPUTED HERE
--
-- `execution_cost` is a prediction about how much there is to do, built from
-- input count, motion length and how often the input method changes. It is not
-- difficulty and is deliberately not called that. Difficulty needs the measured
-- execution leniency alongside these, and that number does not exist until the
-- sweep has run - a one-frame link and a six-frame link look identical from
-- here. Combining them is Phase 8's job, after the game has been asked.
--
-- ONE SCORE, MANY ORDERINGS
--
-- There is no single best route. Highest damage, fewest inputs, no resources
-- spent and best-supported reasoning are four different questions with four
-- different answers, so the score is a table of components and the ranking is a
-- choice of axis over it. `pareto` returns the routes that no other route beats
-- on both damage and execution cost at once, which is the honest version of
-- "the good ones".

local InputMask = require("func/ComboExplorer/core/InputMask")

local M = { name = "ComboExplorer.Scoring" }

-- Weights for execution_cost. Exposed because they are a guess about what makes
-- an input sequence demanding, and a guess should be arguable.
M.WEIGHTS = {
    step            = 1.0,   -- per move in the route
    input           = 0.5,   -- per direction or button press
    motion_digit    = 0.4,   -- per direction in a motion beyond the first
    method_switch   = 2.0,   -- manual -> simple -> assist changes hand position
    repeat_relief   = -0.5,  -- the same move twice is one thing learned, not two
}

local CONF_RANK = { low = 1, medium = 2, high = 3 }
local RANK_NAME = { "low", "medium", "high" }

-- --- per-step input shape ----------------------------------------------------

-- What one step costs to input, from the notation alone. Profile-independent:
-- this counts what is written, and needs no button bit to do it.
--
-- A move whose notation cannot be parsed gets nil rather than zero - zero would
-- make an unparseable move look like the easiest one in the route.
function M.step_inputs(notation)
    local parsed = InputMask.parse(notation)
    if not parsed then return nil end

    local expanded = InputMask.MOTION_SHORTHAND[parsed.dirs] or parsed.dirs
    local digits = 0
    for _ in expanded:gmatch("%d") do digits = digits + 1 end

    return {
        direction_inputs = digits,
        button_presses = #parsed.buttons,
        total = digits + #parsed.buttons,
        -- The part beyond a single direction is what has to be executed as a
        -- motion rather than just held.
        motion_length = (digits > 1) and digits or 0,
        assist = parsed.assist,
        any_button = parsed.any_button,
    }
end

-- --- the score ---------------------------------------------------------------

-- route : a ce.route.v1 from RouteSearch
-- opts.weights : overrides for M.WEIGHTS
--
-- Returns the offline_score table. Does not attach it; see M.apply.
function M.score(route, opts)
    opts = opts or {}
    if type(route) ~= "table" or type(route.steps) ~= "table" then return nil, "not a route" end

    local w = {}
    for k, v in pairs(M.WEIGHTS) do w[k] = v end
    for k, v in pairs(opts.weights or {}) do w[k] = v end

    local input_count, motion_total, hardest = 0, 0, 0
    local unparseable = 0
    local methods = { manual = 0, simple = 0, assist = 0 }
    local switches, repeats = 0, 0

    for i, s in ipairs(route.steps) do
        local shape = M.step_inputs(s.notation or s.classic or "")
        if shape then
            input_count = input_count + shape.total
            motion_total = motion_total + shape.motion_length
            hardest = math.max(hardest, shape.motion_length)
        else
            unparseable = unparseable + 1
        end

        local m = s.input_method or "manual"
        methods[m] = (methods[m] or 0) + 1
        if i > 1 then
            if (route.steps[i - 1].input_method or "manual") ~= m then switches = switches + 1 end
            if route.steps[i - 1].action_id == s.action_id then repeats = repeats + 1 end
        end
    end

    local n = #route.steps
    local basis = route.basis or {}

    -- The frame-table sum, and everything needed to read it honestly. Combo
    -- scaling reduces every hit after the first and appears in no frame table,
    -- so this is an upper bound used for ordering. It is not a damage figure and
    -- must never be exported as one.
    local damage_known = basis.damage_known_steps or 0
    local score = {
        route_length = n,
        input_count = input_count,
        motion_complexity = motion_total,
        hardest_motion = hardest,
        steps_with_unparseable_notation = unparseable,

        input_method_counts = methods,
        input_method_switches = switches,
        simple_ratio = (n > 0) and (methods.simple / n) or 0,
        manual_ratio = (n > 0) and (methods.manual / n) or 0,
        assist_ratio = (n > 0) and (methods.assist / n) or 0,

        predicted_damage = basis.predicted_damage_sum,
        predicted_damage_known_steps = damage_known,
        predicted_damage_complete = (damage_known == n),
        combo_scaling_applied = false,
        -- An unscaled sum bounds the real figure from above only when every
        -- step contributed. Scaling can only reduce, so a complete sum is a
        -- ceiling - but a step the join has no damage for contributed zero, and
        -- zero is not that move's damage. Such a sum is neither a ceiling nor a
        -- floor, and saying "upper bound" of it was a claim nobody could
        -- support: 240 of 1037 Zangief routes carried that flag alongside
        -- predicted_damage_complete = false.
        predicted_damage_bound = (damage_known == n) and "upper" or "none",
        predicted_damage_bound_reason = (damage_known == n)
            and "combo scaling only reduces, so the unscaled sum is a ceiling"
            or ("%d of %d steps contributed no damage figure, so this sum is neither a "
                .. "ceiling nor a floor"):format(n - damage_known, n),
        steps_with_guessed_frame_join = basis.steps_with_guessed_frame_join or 0,

        predicted_drive_gain = basis.predicted_drive_gain,
        predicted_super_gain = basis.predicted_super_gain,
        -- A negative super gain in the source is the cost of using the move,
        -- which is the only spend figure the data actually contains.
        predicted_super_spend = (basis.predicted_super_gain ~= nil
            and basis.predicted_super_gain < 0) and -basis.predicted_super_gain or 0,
        -- The drive cost of an OD move is in no frame table. Left nil rather
        -- than filled with a plausible 3000, and the OD step count stands in
        -- for it so a resource-free ranking still works.
        predicted_drive_spend = nil,
        drive_spend_known = false,
        od_steps = basis.od_steps or 0,
        super_steps = basis.super_steps or 0,

        theoretical_confidence = route.min_confidence,
        confidence_counts = route.confidence_counts,
        steps_with_missing_data = basis.steps_with_missing_data or 0,
        runtime_unknowns = route.requires_runtime_validation
            and #route.requires_runtime_validation or 0,
    }

    -- Not difficulty. See the header: difficulty needs the measured window.
    score.execution_cost =
        n * w.step
        + input_count * w.input
        + motion_total * w.motion_digit
        + switches * w.method_switch
        + repeats * w.repeat_relief
    score.execution_cost_basis = {
        steps = n, inputs = input_count, motion_digits = motion_total,
        method_switches = switches, repeated_moves = repeats, weights = w,
    }
    score.execution_cost_is_prediction = true
    -- No `difficulty` key. Not an oversight: it needs the measured execution
    -- leniency, and a field that exists here would be filled in by somebody.

    return score
end

-- Attaches a score to every route, in place, and hands the list back.
function M.apply(routes, opts)
    for _, r in ipairs(routes or {}) do
        r.offline_score = M.score(r, opts)
    end
    return routes
end

-- --- orderings ---------------------------------------------------------------

M.AXES = {
    DAMAGE        = "predicted_damage",
    SIMPLICITY    = "simplicity",
    CONFIDENCE    = "theoretical_confidence",
    RESOURCE_FREE = "resource_free",
    SHORTEST      = "shortest",
}

-- Higher is better on every axis, so one comparator serves all of them.
local function axis_value(r, axis)
    local s = r.offline_score
    if not s then return -math.huge end
    if axis == M.AXES.DAMAGE then
        return s.predicted_damage or -math.huge
    elseif axis == M.AXES.SIMPLICITY then
        return -s.execution_cost
    elseif axis == M.AXES.CONFIDENCE then
        -- Ties on confidence are common, so damage decides within a band.
        local rank = CONF_RANK[s.theoretical_confidence or "low"] or 1
        return rank * 1e9 - (s.steps_with_missing_data or 0) * 1e6 + (s.predicted_damage or 0)
    elseif axis == M.AXES.RESOURCE_FREE then
        return -(s.od_steps * 1000 + s.super_steps * 1000) + (s.predicted_damage or 0) / 1000
    elseif axis == M.AXES.SHORTEST then
        return -s.route_length
    end
    return -math.huge
end

-- Sorted copy. The route id breaks ties so the same input gives the same
-- ordering every run.
function M.rank(routes, axis, limit)
    local out = {}
    for i, r in ipairs(routes or {}) do out[i] = r end
    table.sort(out, function(a, b)
        local va, vb = axis_value(a, axis), axis_value(b, axis)
        if va ~= vb then return va > vb end
        return tostring(a.id) < tostring(b.id)
    end)
    if limit and #out > limit then
        local cut = {}
        for i = 1, limit do cut[i] = out[i] end
        return cut
    end
    return out
end

-- The routes nothing else beats on both damage and execution cost at once.
-- Preferred over a single blended score because the blend would hide the
-- trade-off that is the whole reason there is more than one route.
function M.pareto(routes)
    -- Sort by damage descending, cost ascending within a tie, then sweep
    -- keeping anything cheaper than everything seen so far. Linear after the
    -- sort, where the obvious pairwise version is quadratic - and the route set
    -- runs to thousands.
    local scored = {}
    for _, r in ipairs(routes or {}) do
        if r.offline_score then scored[#scored + 1] = r end
    end
    table.sort(scored, function(a, b)
        local da, db = a.offline_score.predicted_damage or 0, b.offline_score.predicted_damage or 0
        if da ~= db then return da > db end
        local ca, cb = a.offline_score.execution_cost, b.offline_score.execution_cost
        if ca ~= cb then return ca < cb end
        return tostring(a.id) < tostring(b.id)
    end)

    local out, best_cost = {}, math.huge
    for _, r in ipairs(scored) do
        local c = r.offline_score.execution_cost
        if c < best_cost then
            out[#out + 1] = r
            best_cost = c
        end
    end
    return out
end

-- What the whole set looks like, for the report.
function M.summary(routes)
    local n = 0
    local best_damage, cheapest = nil, nil
    local by_confidence, by_length = {}, {}
    local incomplete_damage = 0
    for _, r in ipairs(routes or {}) do
        local s = r.offline_score
        if s then
            n = n + 1
            if best_damage == nil or (s.predicted_damage or 0) > best_damage then
                best_damage = s.predicted_damage or 0
            end
            if cheapest == nil or s.execution_cost < cheapest then cheapest = s.execution_cost end
            local c = s.theoretical_confidence or "low"
            by_confidence[c] = (by_confidence[c] or 0) + 1
            by_length[s.route_length] = (by_length[s.route_length] or 0) + 1
            if not s.predicted_damage_complete then incomplete_damage = incomplete_damage + 1 end
        end
    end
    return {
        scored = n,
        highest_predicted_damage = best_damage,
        lowest_execution_cost = cheapest,
        by_confidence = by_confidence,
        by_length = by_length,
        routes_with_incomplete_damage = incomplete_damage,
        note = "predicted damage is an unscaled frame-table sum, used for ordering only",
    }
end

M.CONF_RANK = CONF_RANK
M.RANK_NAME = RANK_NAME

return M
