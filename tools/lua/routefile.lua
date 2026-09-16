-- =========================================================
-- tools/lua/routefile.lua - a plan's best routes, written as ce.route.v1 files
-- the game can run. Dev-machine only, like the rest of tools/. Pure: routes and
-- what is known about their pairs in, documents out. No file access.
-- =========================================================
--
-- WHY THIS EXISTS
--
-- runtime/RouteRun.lua runs one named route across a grid of gaps and records
-- every combination, which is what #36 and #37 need: a combo the game has
-- linked, with the damage measured on the run that linked it. It reads
-- reframework/data/ComboExplorer_data/route/*.json - and until now the only two
-- files there were written by hand for #48. The plan knows which routes are
-- worth a pass and the logs know which gaps those routes' pairs have linked at,
-- and nothing carried either into a file the game could run.
--
-- WHAT A ROUTE FILE IS NOT ALLOWED TO DO
--
-- Invent a delay. A single number in `delays` reads as "this is when to press
-- it", and pressing at one unmeasured gap is how #12's first 202 rows produced
-- eight links, all of them Super Arts (#46). So each gap gets a LIST, and where
-- it came from is written into the file:
--
--   measured   the gaps at which the policy's counted runs actually linked this
--              pair (labeval's measured_summary.linked_gaps, which is
--              ConfirmedEdge's by_delay over the runs ce-eval-v1 counted).
--              One or two numbers: the cheapest question there is.
--   predicted  runtime/Sweep.plan_for's own grid for the pair - Timing's cancel
--              window, then the link gap - the same values the sweep would try.
--   default    core/Route.DEFAULT_DELAYS, when the frame data says nothing.
--              Twelve values: the operator's range, not a measurement.
--
-- The grid is the product of the per-gap lists, so a measured gap beside a
-- predicted one is a handful of trials rather than a night.
--
-- WHAT IT REFUSES
--
-- Every route core/Route.build would refuse, before writing it: a Drive Rush
-- Cancel step (no action id anyone agrees on), a step with no notation, a route
-- of one move. A file the game loads and then rejects is worse than no file -
-- it looks like something to run.

local Route = require("func/ComboExplorer/core/Route")

local M = { name = "tools.routefile" }

M.SCHEMA = Route.SCHEMA

M.SOURCE = {
    MEASURED = "measured",
    PREDICTED = "predicted",
    DEFAULT = "default",
}

M.WHY = {
    measured = "the gaps this pair actually linked at, in the runs policy %s counted",
    predicted = "runtime/Sweep.plan_for's grid for this pair: %s",
    default = "core/Route.DEFAULT_DELAYS - nothing measured it and the frame data "
        .. "gives no window (%s)",
}

-- --- what Route.build will take -------------------------------------------------------

-- The reason core/Route.build would refuse this route, or nil. Stated here in
-- the same order and the same words, so a route left out of the write says the
-- thing the game would have said about it.
function M.refusal(route)
    if type(route) ~= "table" or type(route.steps) ~= "table" then
        return "not a route"
    end
    local moves = 0
    for i, s in ipairs(route.steps) do
        if s.kind ~= nil then
            return ("step %d is a %s step, which core/Route.build cannot name: it wants "
                .. "an action id, an input method and a notation on every step")
                :format(i, tostring(s.kind))
        end
        if tonumber(s.action_id) == nil then
            return ("step %d has no numeric action_id"):format(i)
        end
        local m = s.input_method
        if m ~= "manual" and m ~= "simple" and m ~= "assist" then
            return ("step %d: input_method is %q, which is not manual, simple or assist")
                :format(i, tostring(m))
        end
        if type(s.notation) ~= "string" or s.notation == "" then
            return ("step %d has no notation, and without one the route cannot be "
                .. "compiled into inputs"):format(i)
        end
        moves = moves + 1
    end
    if moves < 2 then
        return "a route needs at least two steps - one move is not a combo"
    end
    return nil
end

-- --- where a gap's delays come from -----------------------------------------------------

local function numbers(list)
    local out, seen = {}, {}
    for _, v in ipairs(list or {}) do
        local n = tonumber(v)
        -- A delay key like "40/2" is a ROUTE's gap vector, not one pair's gap,
        -- and tonumber refuses it. Left out rather than half-read.
        if n and not seen[n] then seen[n] = true out[#out + 1] = n end
    end
    table.sort(out)
    return out
end

-- The gaps the policy's counted runs linked this pair at.
--
-- entry : a planner known.pairs / known.groups entry (it carries `evaluations`,
--         one per cohort, each with the linked_gaps labeval measured).
-- Returns delays, why - or nil when nothing linked.
function M.measured_delays(entry, policy_key)
    if type(entry) ~= "table" then return nil end
    local gaps = {}
    for _, ev in ipairs(entry.evaluations or {}) do
        for _, g in ipairs(ev.linked_gaps or {}) do gaps[#gaps + 1] = g end
    end
    local out = numbers(gaps)
    if #out == 0 then return nil end
    return out, M.WHY.measured:format(tostring(policy_key or "ce-eval-v1"))
end

-- How many ticks wide a predicted LINK window may be before only its latest
-- tick is taken. The model's window is `buffer_ticks` wide - five values at the
-- committed bracket of 4 - and every tick of it is worth a trial because the
-- edges are the interesting part (core/Timing.gaps). A window wider than this
-- is a buffer figure nobody measured, and spending the route grid on it would
-- multiply through every other gap.
M.MAX_LINK_SPAN = 8

-- The grid the sweep would try, from the frame data.
--
-- runtime/Sweep.plan_for is the whole rule: the cancel grid for a cancel pair,
-- the cancel grid then the link gap for a pair that could be either, the link
-- gap alone otherwise. A link step is widened from its one gap to the window
-- core/Timing predicted around it - earliest..latest, the ticks the input
-- buffer covers - because the sweep gets to ask the pair again tomorrow and a
-- route run at one gap that whiffs has answered nothing about the route.
-- Nothing outside the model's own window is added: the pad core/Timing.gaps
-- offers is a hedge against the model, and a hedge is not a prediction.
--
-- item     : a worklist item for the pair (Pipeline.worklist_item)
-- plan_for : runtime/Sweep.plan_for. Handed in rather than required, because a
--            route file has no business loading the runtime to be tested.
-- Returns delays, why - or nil when the frame data gives no window.
function M.predicted_delays(item, plan_for, opts)
    if type(item) ~= "table" or type(plan_for) ~= "function" then return nil end
    local ok, steps = pcall(plan_for, item, opts or { hold_ticks = 3 })
    if not ok or type(steps) ~= "table" then return nil end
    local delays, kinds, seen = {}, {}, {}
    local function add(n, kind)
        if not n or seen[n] then return end
        seen[n] = true
        delays[#delays + 1] = n
        if not kinds[kind] then kinds[kind] = true kinds[#kinds + 1] = kind end
    end
    for _, s in ipairs(steps) do
        local why = s.why or {}
        -- An unpredicted step is the sweep saying it has no window and will
        -- press at whatever the panel is set to. That is not a prediction.
        if why.predicted then
            local w = type(why.window) == "table" and why.window or nil
            local lo = w and tonumber(w.earliest)
            local hi = w and tonumber(w.latest)
            if why.prediction == "link" and lo and hi and hi >= lo
                and (hi - lo) <= M.MAX_LINK_SPAN then
                for g = lo, hi do add(g, "the predicted link window") end
            else
                add(tonumber(s.delay), ("the predicted %s gap"):format(
                    tostring(why.prediction or "?")))
            end
        end
    end
    if #delays == 0 then return nil end
    table.sort(delays)
    return delays, M.WHY.predicted:format(table.concat(kinds, ", then "))
end

-- measured, else predicted, else the default range. Never one invented number:
-- the last fallback is the same list the sweep would try when it knows nothing.
--
-- deps.entry, deps.item, deps.plan_for, deps.policy_key, deps.sweep_opts
-- Returns { delays, source, why }.
function M.delays_for(deps)
    deps = deps or {}
    local d, why = M.measured_delays(deps.entry, deps.policy_key)
    if d then return { delays = d, source = M.SOURCE.MEASURED, why = why } end
    d, why = M.predicted_delays(deps.item, deps.plan_for, deps.sweep_opts)
    if d then return { delays = d, source = M.SOURCE.PREDICTED, why = why } end
    local copy = {}
    for i, v in ipairs(Route.DEFAULT_DELAYS) do copy[i] = v end
    return { delays = copy, source = M.SOURCE.DEFAULT,
             why = M.WHY.default:format(deps.no_window_reason
                 or "no measurement and no predicted window") }
end

-- --- the document -----------------------------------------------------------------------

local function combinations(gaps)
    local n = 1
    for _, g in ipairs(gaps) do n = n * #g.delays end
    return n
end

-- route : a scored route from the search (steps with action_id, input_method,
--         notation; a step with a `kind` is what makes it unwritable)
-- opts.id, opts.character, opts.control_scheme   the route's identity
-- opts.gaps      one entry per gap, in order, each { delays, source, why } -
--                usually M.delays_for's return
-- opts.plan      { name, rank, sort, generated_at, tool, conditions }
-- opts.status    what the logs already say about the whole combo, one line
--
-- Returns doc, info - or nil and the reason Route.build would have refused it.
function M.build(route, opts)
    opts = opts or {}
    local why = M.refusal(route)
    if why then return nil, why end

    local steps = {}
    for i, s in ipairs(route.steps) do
        steps[i] = {
            action_id = math.tointeger(tonumber(s.action_id)) or tonumber(s.action_id),
            input_method = s.input_method,
            notation = s.notation,
        }
    end

    local gaps = opts.gaps or {}
    if #gaps ~= #steps - 1 then
        return nil, ("this route has %d gap(s) and %d list(s) of delays were given")
            :format(#steps - 1, #gaps)
    end

    local delays, lines, by_source = {}, {}, {}
    for i, g in ipairs(gaps) do
        if type(g.delays) ~= "table" or #g.delays == 0 then
            return nil, ("the delay list for gap %d is empty"):format(i)
        end
        local copy = {}
        for j, v in ipairs(g.delays) do copy[j] = v end
        delays[i] = copy
        by_source[g.source] = (by_source[g.source] or 0) + 1
        local names = {}
        for j, v in ipairs(copy) do names[j] = tostring(v) end
        lines[#lines + 1] = ("gap %d (%s -> %s): %s from %s - %s")
            :format(i, tostring(steps[i].notation), tostring(steps[i + 1].notation),
                    table.concat(names, ", "), tostring(g.source), tostring(g.why))
    end

    local head = ("Written by tools/lua/plan.lua --routes from plan %s (rank %s). "
        .. "Every gap is a LIST, never one number: a single delay would read as a "
        .. "measurement, and pressing at one unmeasured gap is how a cancel window "
        .. "gets mistaken for a link window (#46). Where each list came from:")
        :format(tostring(opts.plan and opts.plan.name or "?"),
                tostring(opts.plan and opts.plan.rank or "?"))

    local note = head .. "\n" .. table.concat(lines, "\n")
    if opts.status then note = note .. "\nWhat the logs already say: " .. tostring(opts.status) end
    note = note .. ("\nThe grid is %d combination(s). EVERY ROUTE IN A PLAN IS A "
        .. "PREDICTION: this file is a question for the game, not a combo.")
        :format(combinations(gaps))

    local doc = {
        schema = M.SCHEMA,
        id = tostring(opts.id),
        character = opts.character,
        control_scheme = opts.control_scheme or "modern",
        note = note,
        steps = steps,
        delays = delays,
        -- Beside the route, not inside it: core/Route.build reads none of this,
        -- and a later reader should not have to parse the note to find out
        -- which plan asked for the file or how sure each gap is.
        plan = opts.plan,
        gaps = (function()
            local out = {}
            for i, g in ipairs(gaps) do
                out[i] = { pair = g.pair, source = g.source, why = g.why,
                           delays = delays[i] }
            end
            return out
        end)(),
    }
    return doc, { combinations = combinations(gaps), by_source = by_source,
                  steps = #steps, gaps = #gaps }
end

-- The name the file is written under: <char>-<scheme>-<plan>-<rank>.json.
function M.file_name(char_lc, scheme, plan_name, rank)
    return ("%s-%s-%s-%d"):format(tostring(char_lc), tostring(scheme),
                                  tostring(plan_name), rank)
end

return M
