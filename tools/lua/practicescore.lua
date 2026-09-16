-- =========================================================
-- tools/lua/practicescore.lua - the arithmetic behind
-- docs/ComboExplorer/practice.md: per character, five components built from
-- the offline route scores and the committed worklists, normalised across the
-- roster, and combined into one number.
--
-- Pure. No io, no require, no game. tools/lua/practice.lua does the reading
-- and the writing; everything a reader might want to argue with is here.
-- =========================================================
--
-- WHAT THIS NUMBER IS, AND WHAT IT IS NOT
--
-- It is a PREDICTED EXECUTION EASE: a guess, from the frame table and the
-- shape of the inputs, about how much there is to do and how much room the
-- frame numbers leave to do it in. It is not measured difficulty and must
-- never be printed without the word "predicted".
--
-- The reason is in core/Scoring.lua's header and it has not changed: nobody
-- has measured a single link's window on this build. A one-frame link and a
-- six-frame link are the same shape from here; all the data offers is
-- margin_frames, which is a subtraction over two frame-table rows, and the
-- mechanism, which says whether the game will cancel for you. Only Zangief has
-- trials at all (6 confirmed combos out of 1000 attempts), so there is nothing
-- to calibrate against for the other 30 characters.
--
-- So the ranking is a hypothesis to be tested by sweeping, not a result.
--
-- HOW THE COMPONENTS COMBINE
--
--   raw metrics  ->  signals  ->  min-max normalised 0..1  ->  weighted mean
--
-- Every signal is min-max normalised ACROSS THE CHARACTERS PRESENT, so 1.00 is
-- the best character in this set and 0.00 the worst, on that signal. Two
-- consequences a reader should hold on to:
--
--   * the bottom of every component is 0 by construction, not because the
--     character is bad at it in any absolute sense;
--   * drop a character from the run and everyone else's numbers move.
--
-- z-scores were the alternative. Min-max won because several signals are
-- heavily skewed by one or two characters (Guile's 2797 worklist pairs,
-- Dhalsim's 2681 routes) and a z-score over a skewed distribution reads as a
-- precise statement about a distribution that is not normal. Min-max at least
-- says plainly what it is: a position between the extremes of this roster.
-- Route counts are log-scaled before normalising for the same reason.
--
-- MISSING DATA IS A FLAG, NOT A ZERO
--
-- A component that could not be computed - no routes, no worklist, no route
-- carried a scaled damage figure - is nil. nil is dropped from the weighted
-- mean and the remaining weights are renormalised, and the character carries
-- an `incomplete` flag naming what is missing. Scoring it zero would put a
-- character with no data at the bottom of a difficulty ranking, which is a
-- claim about the character rather than about the data.

local M = { name = "tools.practicescore" }

-- --- the weights -------------------------------------------------------------
--
-- The whole point of publishing these is that a reader can disagree. The
-- report prints every component beside the total so the disagreement can be
-- acted on without rerunning anything.

M.WEIGHTS = {
    -- The largest share, because a route nobody would use is not practice. A
    -- character whose CHEAP routes already do damage gives a learner something
    -- back for the first thing they learn; one whose damage all sits behind
    -- expensive routes makes the first week feel pointless.
    easy_damage = 0.30,

    -- What the hands actually do: how many inputs, how long the motions, how
    -- often the grip changes. This is the only execution signal in the data
    -- that is not a guess about a window - it is counted off the notation.
    input_shape = 0.25,

    -- The frame margins are the closest thing to a link window the data has,
    -- and the mechanism says whether the game is cancelling for you. Weighted
    -- equal to input shape because timing and motion are the two halves of
    -- execution and there is no evidence here for preferring one.
    timing_comfort = 0.25,

    -- Having many routes that need no OD, no super and no Drive Rush means you
    -- can drill without also learning resource management. Small, because a
    -- count of unverified candidates is a measure of the search, not of the
    -- character.
    route_availability = 0.10,

    -- A character whose numbers are shaky should not out-rank one whose
    -- numbers hold. Small and deliberately last, because the quality of our
    -- frame-data join is a property of this repo, not of the character - it
    -- nudges the order, and the flags say the rest.
    data_quality = 0.10,
}

-- Inside component 1. Even, because "the best cheap route" and "the best
-- damage per unit of cost anywhere on the front" are two readings of the same
-- question and neither is obviously the right one.
M.EASY_DAMAGE_WEIGHTS = {
    best_cheap_damage = 0.5,   -- higher is easier
    best_pareto_ratio = 0.5,   -- higher is easier
}

-- Inside component 2. Input count and motion length carry most of it because
-- they are what a learner repeats; the 4+ direction share is called out
-- separately because a 360 is a different kind of problem from a long string
-- of quarter-circles, and a method switch is a hand moving, which costs more
-- than one more press.
M.SHAPE_WEIGHTS = {
    mean_input_count      = 0.30,  -- lower is easier
    mean_hardest_motion   = 0.25,  -- lower is easier
    big_motion_share      = 0.20,  -- lower is easier
    mean_method_switches  = 0.15,  -- lower is easier
    simple_share          = 0.10,  -- HIGHER is easier: a Modern SP press is one button
}

-- Inside component 5. The join and the confidence share are the two figures
-- all.lua already publishes per character, so a reader can check them in
-- characters.json; the guessed-join share is about the routes actually being
-- ranked and is smaller because it is usually tiny.
M.QUALITY_WEIGHTS = {
    join_share        = 0.40,  -- higher is better
    confident_share   = 0.40,  -- higher is better (1 - low-confidence share)
    exact_join_share  = 0.20,  -- higher is better (1 - guessed-join share)
}

M.DEFAULTS = {
    -- The cheap-route cut, as a quantile of the POOLED execution_cost of every
    -- route of every character. A per-character quantile would make every
    -- character have cheap routes by definition.
    cheap_quantile = 0.25,
    -- How many routes count as "the good ones" for component 2. 25 is about
    -- the size of a plan preset (batch.lua's plans run 8-26 pairs), so it is
    -- roughly what somebody would actually take to the lab.
    top_n = 25,
    -- A link with this much margin or more is called comfortable. Three frames
    -- is the usual hand-wringing threshold in fighting-game write-ups; it is a
    -- convention, not a measurement, and it is exposed so it can be moved.
    comfortable_margin = 3,
    -- A motion with this many directions or more is the "big motion" share:
    -- 360 / 720 / 63214 and friends.
    big_motion_digits = 4,
    -- Flag thresholds.
    weak_join = 0.90,
    heavy_low_confidence = 0.60,
}

-- --- small numeric helpers ---------------------------------------------------

-- Linear-interpolated quantile over a copy of `values`, sorted here. Returns
-- nil for an empty list rather than 0: "the 25th percentile of nothing" has no
-- answer, and 0 would silently make every route expensive.
function M.quantile(values, q)
    local v = {}
    for _, x in ipairs(values or {}) do
        if type(x) == "number" then v[#v + 1] = x end
    end
    if #v == 0 then return nil end
    table.sort(v)
    if #v == 1 then return v[1] end
    local pos = 1 + (#v - 1) * math.max(0, math.min(1, q or 0))
    local lo = math.floor(pos)
    local hi = math.ceil(pos)
    if lo == hi then return v[lo] end
    return v[lo] + (v[hi] - v[lo]) * (pos - lo)
end

local function mean(values)
    local n, sum = 0, 0
    for _, x in ipairs(values or {}) do
        if type(x) == "number" then n = n + 1; sum = sum + x end
    end
    if n == 0 then return nil end
    return sum / n
end
M.mean = mean

-- --- route summaries ---------------------------------------------------------

-- One ce.route.v1 with its offline_score, reduced to the dozen numbers the
-- components use. practice.lua keeps these instead of the routes: 34,625
-- routes across the roster, each carrying its steps and a per-step scaling
-- breakdown, is a lot of memory to hold for fifteen numbers.
--
-- Returns nil for a route with no offline_score - it was never scored, so it
-- cannot be summarised, and a zeroed summary would be a cheap perfect route.
function M.route_summary(route)
    if type(route) ~= "table" then return nil end
    local s = route.offline_score
    if type(s) ~= "table" then return nil end
    return {
        id = route.id,
        cost = s.execution_cost,
        damage = s.predicted_damage,
        damage_scaled = s.predicted_damage_scaled,
        length = s.route_length,
        inputs = s.input_count,
        hardest_motion = s.hardest_motion,
        switches = s.input_method_switches,
        simple_ratio = s.simple_ratio,
        od_steps = s.od_steps or 0,
        super_steps = s.super_steps or 0,
        drc_steps = s.drive_rush_cancel_steps or 0,
        guessed_join = s.steps_with_guessed_frame_join or 0,
        missing_data = s.steps_with_missing_data or 0,
        confidence = s.theoretical_confidence,
    }
end

function M.route_summaries(routes)
    local out = {}
    for _, r in ipairs(routes or {}) do
        local s = M.route_summary(r)
        if s then out[#out + 1] = s end
    end
    return out
end

-- The `top_n` summaries with the highest predicted_damage_scaled. Routes with
-- no scaled figure are left out rather than sorted to the bottom: the question
-- is "what do the good routes look like", and a route whose damage is unknown
-- is not known to be good or bad.
function M.top_by_damage(summaries, n)
    local with = {}
    for _, s in ipairs(summaries or {}) do
        if type(s.damage_scaled) == "number" then with[#with + 1] = s end
    end
    table.sort(with, function(a, b)
        if a.damage_scaled ~= b.damage_scaled then return a.damage_scaled > b.damage_scaled end
        if (a.cost or 0) ~= (b.cost or 0) then return (a.cost or 0) < (b.cost or 0) end
        return tostring(a.id) < tostring(b.id)
    end)
    local limit = math.min(n or #with, #with)
    local out = {}
    for i = 1, limit do out[i] = with[i] end
    return out
end

-- --- component 1: easy damage ------------------------------------------------

-- "How much damage is available at the cheap end, and how good is the best
-- deal on the Pareto front."
--
-- summaries : every route summary for this character
-- pareto    : the summaries of Scoring.pareto(routes) - the routes nothing
--             else beats on damage and execution cost at once
-- threshold : the pooled cheap-route cut, from M.quantile
function M.easy_damage(summaries, pareto, threshold)
    local cheap, cheap_with_damage, best = 0, 0, nil
    for _, s in ipairs(summaries or {}) do
        if type(s.cost) == "number" and threshold and s.cost <= threshold then
            cheap = cheap + 1
            if type(s.damage_scaled) == "number" then
                cheap_with_damage = cheap_with_damage + 1
                if best == nil or s.damage_scaled > best then best = s.damage_scaled end
            end
        end
    end
    local best_ratio, ratios = nil, {}
    for _, s in ipairs(pareto or {}) do
        if type(s.damage_scaled) == "number" and type(s.cost) == "number" and s.cost > 0 then
            local r = s.damage_scaled / s.cost
            ratios[#ratios + 1] = r
            if best_ratio == nil or r > best_ratio then best_ratio = r end
        end
    end
    return {
        cheap_threshold = threshold,
        routes = #(summaries or {}),
        cheap_routes = cheap,
        cheap_routes_with_damage = cheap_with_damage,
        best_cheap_damage = best,
        pareto_routes = #(pareto or {}),
        pareto_routes_with_damage = #ratios,
        best_pareto_ratio = best_ratio,
        mean_pareto_ratio = mean(ratios),
    }
end

-- --- component 2: the input shape of the good routes -------------------------

-- What the top routes by scaled damage ask the hands to do. Nil when no route
-- carried a scaled damage figure at all.
function M.input_shape(summaries, opts)
    opts = opts or {}
    local big = opts.big_motion_digits or M.DEFAULTS.big_motion_digits
    local top = M.top_by_damage(summaries, opts.top_n or M.DEFAULTS.top_n)
    if #top == 0 then return nil end
    local inputs, hardest, switches = {}, {}, {}
    local big_n, simple_n = 0, 0
    for _, s in ipairs(top) do
        inputs[#inputs + 1] = s.inputs
        hardest[#hardest + 1] = s.hardest_motion
        switches[#switches + 1] = s.switches
        if (s.hardest_motion or 0) >= big then big_n = big_n + 1 end
        if (s.simple_ratio or 0) > 0 then simple_n = simple_n + 1 end
    end
    return {
        top_n = #top,
        mean_input_count = mean(inputs),
        mean_hardest_motion = mean(hardest),
        big_motion_routes = big_n,
        big_motion_share = big_n / #top,
        mean_method_switches = mean(switches),
        simple_routes = simple_n,
        simple_share = simple_n / #top,
    }
end

-- --- component 3: timing comfort (predicted) ---------------------------------

-- Over the committed worklist pairs. Every number here is a count of pairs, so
-- it can be checked against worklist/<char>-modern.json by hand.
--
-- "Forgiving" is a cancel, a pair that is both cancellable and linkable, or a
-- link whose margin_frames is at least `comfortable_margin`. A cancel window
-- is generally wider than a link and the sweep times the two differently
-- (be1c0be), so the mechanism is the first cut and the margin is the second.
--
-- An `unknown` pair - the frame join had no numbers for it - counts against
-- the forgiving share. That is deliberate and it does mean component 3 carries
-- some of the same information as component 5: a pair nobody can put a number
-- on is not a comfortable pair, whatever the reason.
function M.timing_comfort(wl_pairs, opts)
    opts = opts or {}
    local comfy = opts.comfortable_margin or M.DEFAULTS.comfortable_margin
    local total = #(wl_pairs or {})
    if total == 0 then return nil end
    local by_mech = { link = 0, cancel = 0, both = 0, unknown = 0 }
    local comfortable, tight, negative, no_margin = 0, 0, 0, 0
    for _, p in ipairs(wl_pairs) do
        local m = p.mechanism
        if by_mech[m] == nil then m = "unknown" end
        by_mech[m] = by_mech[m] + 1
        if m == "link" then
            local mf = p.margin_frames
            if type(mf) ~= "number" then no_margin = no_margin + 1
            elseif mf >= comfy then comfortable = comfortable + 1
            elseif mf >= 1 then tight = tight + 1
            else negative = negative + 1 end
        end
    end
    local links = by_mech.link
    return {
        pairs = total,
        link_pairs = links,
        cancel_pairs = by_mech.cancel,
        both_pairs = by_mech.both,
        unknown_pairs = by_mech.unknown,
        comfortable_margin = comfy,
        comfortable_links = comfortable,
        tight_links = tight,
        negative_links = negative,
        links_without_margin = no_margin,
        comfortable_link_share = links > 0 and comfortable / links or nil,
        tight_link_share = links > 0 and tight / links or nil,
        cancel_share = by_mech.cancel / total,
        unknown_share = by_mech.unknown / total,
        -- The single signal the component is normalised on.
        forgiving_share = (by_mech.cancel + by_mech.both + comfortable) / total,
    }
end

-- --- component 4: route availability -----------------------------------------

-- How much there is to practise, and how much of it needs no meter.
--
-- "No gauge" is computed here from the offline_score fields - od_steps,
-- super_steps, drive_rush_cancel_steps all zero - and NOT from planner.lua's
-- no-gauge preset, which is another tool's definition and another agent's
-- file. The two can disagree; this one is stated so it can be checked.
function M.route_availability(summaries)
    local total = #(summaries or {})
    if total == 0 then return nil end
    local three, no_gauge, three_no_gauge = 0, 0, 0
    for _, s in ipairs(summaries) do
        local free = (s.od_steps or 0) == 0 and (s.super_steps or 0) == 0
            and (s.drc_steps or 0) == 0
        if s.length == 3 then three = three + 1 end
        if free then no_gauge = no_gauge + 1 end
        if s.length == 3 and free then three_no_gauge = three_no_gauge + 1 end
    end
    return {
        routes = total,
        three_move_routes = three,
        no_gauge_routes = no_gauge,
        no_gauge_share = no_gauge / total,
        three_move_no_gauge_routes = three_no_gauge,
    }
end

-- --- component 5: data quality -----------------------------------------------

-- How much of this character's ranking rests on numbers that are actually
-- there. `row` is the character's row from docs/ComboExplorer/characters.json.
function M.data_quality(summaries, row, truncated, opts)
    opts = opts or {}
    row = row or {}
    local cov = row.coverage
    local join = (cov and cov.rows and cov.rows > 0) and (cov.matched / cov.rows) or nil
    local conf = row.worklist_confidence
    local wl = row.worklist_pairs
    local low_share = (conf and wl and wl > 0) and ((conf.low or 0) / wl) or nil

    local top = M.top_by_damage(summaries, opts.top_n or M.DEFAULTS.top_n)
    local steps, guessed, missing = 0, 0, 0
    for _, s in ipairs(top) do
        steps = steps + (s.length or 0)
        guessed = guessed + (s.guessed_join or 0)
        missing = missing + (s.missing_data or 0)
    end
    local guessed_share = steps > 0 and (guessed / steps) or nil

    return {
        join_share = join,
        join_matched = cov and cov.matched,
        join_rows = cov and cov.rows,
        worklist_pairs = wl,
        low_confidence_pairs = conf and conf.low,
        low_confidence_share = low_share,
        confident_share = low_share and (1 - low_share) or nil,
        top_n = #top,
        top_steps = steps,
        guessed_join_steps = guessed,
        guessed_join_share = guessed_share,
        exact_join_share = guessed_share and (1 - guessed_share) or nil,
        missing_data_steps = missing,
        -- Not folded into the number: the beam cuts the search short for most
        -- of the roster, so a penalty here would be a penalty on nearly
        -- everyone. It is a flag instead.
        search_truncated = truncated == true,
    }
end

-- --- normalisation -----------------------------------------------------------

-- Min-max over the values that are not nil. `higher_is_better = false` flips
-- it. When every present value is identical the result is 0.5 for all of them:
-- 1.0 would say they are all the best and 0.0 that they are all the worst, and
-- neither is true when there is no spread to read.
function M.normalise(values, higher_is_better)
    local lo, hi
    for _, v in pairs(values or {}) do
        if type(v) == "number" then
            if lo == nil or v < lo then lo = v end
            if hi == nil or v > hi then hi = v end
        end
    end
    local out = {}
    if lo == nil then return out end
    for k, v in pairs(values) do
        if type(v) == "number" then
            local t
            if hi == lo then t = 0.5 else t = (v - lo) / (hi - lo) end
            out[k] = (higher_is_better == false) and (1 - t) or t
        end
    end
    return out
end

-- A weighted mean over the parts that are present, with the present weights
-- renormalised. Returns the value and the share of the total weight that was
-- available, so a caller can tell a complete 0.7 from a 0.7 built on a third
-- of the weights.
function M.weighted(parts, weights)
    local sum, wsum, total = 0, 0, 0
    for k, w in pairs(weights or {}) do
        total = total + w
        local v = parts and parts[k]
        if type(v) == "number" then
            sum = sum + v * w
            wsum = wsum + w
        end
    end
    if wsum == 0 then return nil, 0 end
    return sum / wsum, (total > 0) and (wsum / total) or 0
end

-- --- flags -------------------------------------------------------------------

M.COMPONENT_LABELS = {
    easy_damage = "easy damage",
    input_shape = "input shape",
    timing_comfort = "timing comfort",
    route_availability = "route availability",
    data_quality = "data quality",
}

-- What makes a character's numbers weaker than they look, as data rather than
-- as a sentence: `kind` plus the figures it was raised on. The page and the
-- report are written in different languages, and a flag that arrives as
-- English prose can only be printed in English.
--
-- `raw` is one character's table of component raws.
function M.flags(raw, opts)
    opts = opts or {}
    local weak_join = opts.weak_join or M.DEFAULTS.weak_join
    local heavy_low = opts.heavy_low_confidence or M.DEFAULTS.heavy_low_confidence
    local out = {}
    local q = raw and raw.data_quality
    if q then
        if type(q.join_share) == "number" and q.join_share < weak_join then
            out[#out + 1] = { kind = "weak_join", share = q.join_share,
                              matched = q.join_matched or 0, rows = q.join_rows or 0 }
        end
        if type(q.low_confidence_share) == "number" and q.low_confidence_share >= heavy_low then
            out[#out + 1] = { kind = "low_confidence", share = q.low_confidence_share }
        end
        if q.search_truncated then
            out[#out + 1] = { kind = "search_truncated" }
        end
    end
    local missing = {}
    for key in pairs(M.WEIGHTS) do
        if raw == nil or raw[key] == nil then missing[#missing + 1] = M.COMPONENT_LABELS[key] end
    end
    table.sort(missing)
    if #missing > 0 then
        out[#out + 1] = { kind = "incomplete", components = missing }
    end
    return out
end

-- The English phrasing, for practice.md. The page has its own.
function M.flag_text(f)
    if type(f) ~= "table" then return tostring(f) end
    if f.kind == "weak_join" then
        return ("frame-data join %d/%d (%.0f%%)"):format(f.matched, f.rows, f.share * 100)
    elseif f.kind == "low_confidence" then
        return ("%.0f%% of the worklist is low confidence"):format(f.share * 100)
    elseif f.kind == "search_truncated" then
        return "route search hit the beam limit"
    elseif f.kind == "incomplete" then
        return "no " .. table.concat(f.components, ", ") .. " (component not scored)"
    end
    return tostring(f.kind)
end

function M.flag_texts(flags)
    local out = {}
    for i, f in ipairs(flags or {}) do out[i] = M.flag_text(f) end
    return out
end

-- --- the ranking -------------------------------------------------------------

-- The signals each component is normalised on, and which way is easier.
-- Exposed so the report can print the same list it scored on.
M.SIGNALS = {
    easy_damage = {
        { key = "best_cheap_damage", higher_is_better = true,
          weight_key = "best_cheap_damage", weights = "EASY_DAMAGE_WEIGHTS" },
        { key = "best_pareto_ratio", higher_is_better = true,
          weight_key = "best_pareto_ratio", weights = "EASY_DAMAGE_WEIGHTS" },
    },
    input_shape = {
        { key = "mean_input_count", higher_is_better = false, weights = "SHAPE_WEIGHTS" },
        { key = "mean_hardest_motion", higher_is_better = false, weights = "SHAPE_WEIGHTS" },
        { key = "big_motion_share", higher_is_better = false, weights = "SHAPE_WEIGHTS" },
        { key = "mean_method_switches", higher_is_better = false, weights = "SHAPE_WEIGHTS" },
        { key = "simple_share", higher_is_better = true, weights = "SHAPE_WEIGHTS" },
    },
    timing_comfort = {
        { key = "forgiving_share", higher_is_better = true },
    },
    route_availability = {
        { key = "no_gauge_routes", higher_is_better = true, log = true },
    },
    data_quality = {
        { key = "join_share", higher_is_better = true, weights = "QUALITY_WEIGHTS" },
        { key = "confident_share", higher_is_better = true, weights = "QUALITY_WEIGHTS" },
        { key = "exact_join_share", higher_is_better = true, weights = "QUALITY_WEIGHTS" },
    },
}

-- chars : { { character = "Ryu", lc = "ryu", raw = { easy_damage = {...}, ... } }, ... }
-- opts.weights : overrides for M.WEIGHTS
--
-- Returns the same list, each entry gaining:
--   components  : { [component] = 0..1 or nil }
--   signals     : { [component] = { [signal] = 0..1 } } - the normalised parts
--   score       : 0..100, or nil when nothing could be scored
--   coverage    : the share of M.WEIGHTS that was available
--   flags       : M.flags
--   rank        : 1..n, by score descending, character name breaking ties
--   damage_rank : 1..n, by the easy-damage component alone
function M.rank(chars, opts)
    opts = opts or {}
    local W = {}
    for k, v in pairs(M.WEIGHTS) do W[k] = v end
    for k, v in pairs(opts.weights or {}) do W[k] = v end

    local subweights = {
        EASY_DAMAGE_WEIGHTS = M.EASY_DAMAGE_WEIGHTS,
        SHAPE_WEIGHTS = M.SHAPE_WEIGHTS,
        QUALITY_WEIGHTS = M.QUALITY_WEIGHTS,
    }

    for _, c in ipairs(chars or {}) do
        c.components, c.signals = {}, {}
    end

    -- Normalise each signal across the roster, then fold the signals of a
    -- component into that component's number.
    for comp, signals in pairs(M.SIGNALS) do
        local normalised = {}
        for _, sig in ipairs(signals) do
            local column = {}
            for i, c in ipairs(chars or {}) do
                local raw = c.raw and c.raw[comp]
                local v = raw and raw[sig.key]
                if type(v) == "number" then
                    column[i] = sig.log and math.log(1 + math.max(0, v)) or v
                end
            end
            normalised[sig.key] = M.normalise(column, sig.higher_is_better)
        end
        for i, c in ipairs(chars or {}) do
            if c.raw and c.raw[comp] then
                local parts, weights = {}, {}
                for _, sig in ipairs(signals) do
                    parts[sig.key] = normalised[sig.key][i]
                    local set = sig.weights and subweights[sig.weights]
                    weights[sig.key] = set and set[sig.weight_key or sig.key] or 1
                end
                c.signals[comp] = parts
                c.components[comp] = (M.weighted(parts, weights))
            end
        end
    end

    for _, c in ipairs(chars or {}) do
        local value, coverage = M.weighted(c.components, W)
        c.score = value and (value * 100) or nil
        c.coverage = coverage
        c.flags = M.flags(c.raw, opts)
    end

    local function ordered(key)
        local out = {}
        for i, c in ipairs(chars or {}) do out[i] = c end
        table.sort(out, function(a, b)
            local va = (key == "score") and a.score or (a.components and a.components.easy_damage)
            local vb = (key == "score") and b.score or (b.components and b.components.easy_damage)
            -- An unscored character sorts last rather than first; the flag,
            -- not the position, is what says why.
            va = va or -math.huge
            vb = vb or -math.huge
            if va ~= vb then return va > vb end
            return tostring(a.character) < tostring(b.character)
        end)
        return out
    end

    for i, c in ipairs(ordered("score")) do c.rank = i end
    for i, c in ipairs(ordered("damage")) do c.damage_rank = i end

    local out = ordered("score")
    return out
end

return M
