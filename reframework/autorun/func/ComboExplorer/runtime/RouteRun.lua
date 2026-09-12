-- =========================================================
-- ComboExplorer/runtime/RouteRun.lua - one named route, at every gap.
-- =========================================================
--
-- WHAT THIS IS FOR
--
-- #48. An operator says "アシスト强 > 3中 > 2必殺技 is a combo I know connects".
-- That is a ground truth, and it is the only thing that can show this pipeline
-- is able to see a LINK at all - #12's first 202 rows found 8 and every one was
-- a Super Art, because at gap 4 the second input lands inside the first move's
-- animation, which is a cancel window (#46).
--
-- WHY IT IS NOT Sweep
--
-- Sweep walks a worklist of PAIRS and builds a two-step route for each. This
-- walks one route of N steps across a grid of gaps. The queue is the only thing
-- they have in common and it is four lines; sharing it would mean teaching
-- Sweep about routes, which is the larger half of Sweep and none of its
-- purpose.
--
-- WHY A GRID AND NOT A LIST
--
-- A three-move route has two gaps and they are not the same question: the gap
-- into a special is not the gap into a normal. Walking two lists in step tries
-- (2,2), (4,4), (6,6) and never (2,6) - and "does this connect at all" is
-- exactly the question that needs the combinations. core/Route.delay_grid.
--
-- WHY EVERY COMBINATION IS RECORDED, INCLUDING THE FAILURES
--
-- The answer being looked for is "at least one gap linked". A file containing
-- only the gaps that worked cannot distinguish "one gap in a hundred" from
-- "every gap tried", and the first of those is a combo with a one-frame window
-- while the second is a route that always connects. Both are findings and they
-- are not the same finding.

local Route = require("func/ComboExplorer/core/Route")
local ResultCollector = require("func/ComboExplorer/core/ResultCollector")
local Catalog = require("func/ComboExplorer/core/Catalog")

local M = { name = "ComboExplorer.RouteRun" }

local _injector = nil
local function default_injector()
    if _injector == nil then
        _injector = require("func/ComboExplorer/runtime/Injector")
    end
    return _injector
end

local run = nil

-- How many times a combination that came back retryable may come back.
--
-- A retryable outcome is the trial saying it measured nothing - the stage would
-- not reset, the gate shut mid-trial. Unlimited retries would turn one bad
-- combination into a loop that looks exactly like progress.
M.DEFAULT_MAX_ATTEMPTS = 3

-- opts.route          : a built route (core/Route.build)
-- opts.delays         : the values each gap is tried at. Defaults to
--                       Route.DEFAULT_DELAYS.
-- opts.collector      : a ResultCollector. Required, same reason as Sweep.
-- opts.provenance     : the register, passed to every trial
-- opts.allow_injection / opts.stage_cfg / opts.sink : passed through
-- opts.injector       : substituted by tests
function M.start(opts)
    opts = opts or {}
    if run then return nil, "a route run is already going" end

    local route = opts.route
    if type(route) ~= "table" or type(route.steps) ~= "table" or #route.steps < 2 then
        return nil, "no route - build one with core/Route.build first"
    end
    if type(opts.collector) ~= "table" then
        return nil, "no collector - a run that cannot record is a run that did not happen"
    end

    local gaps = #route.steps - 1
    local grid, note = Route.delay_grid(gaps, opts.delays or route.delays)
    if #grid == 0 then
        return nil, "the delay grid is empty, so there is nothing to try"
    end

    run = {
        injector = opts.injector or default_injector(),
        route = route,
        -- For expected_for. Absent is a real case - a run before a battle
        -- resolves the catalog - and costs the group expansion, not the run.
        catalog = opts.catalog,
        grid = grid,
        -- Carried, not swallowed. A capped grid that says nothing reads as a
        -- completed search.
        grid_note = note,
        collector = opts.collector,
        provenance = opts.provenance,
        allow_injection = opts.allow_injection,
        stage_cfg = opts.stage_cfg,
        sink = opts.sink,
        max_attempts = opts.max_attempts or M.DEFAULT_MAX_ATTEMPTS,

        index = 1,
        attempts = {},
        started = 0,
        finished = 0,
        links = 0,
        problems = {},
        by_verdict = {},
        linked_at = {},
        done = false,
        stopped_because = nil,
    }
    return true
end

function M.stop() run = nil end
function M.running() return run ~= nil end

local function key_for(delays)
    local parts = {}
    for i, d in ipairs(delays) do parts[i] = tostring(d) end
    return table.concat(parts, "/")
end
M.key_for = key_for

-- Expected action ids, one list per step, from the route itself.
--
-- The route is what the operator said they wanted pressed, so it is also what
-- must come out. Building this anywhere else would be a second statement of the
-- same intent, free to disagree with the first.
--
-- WHY THE WHOLE NOTATION GROUP, NOT THE ONE ID THE FILE NAMES
--
-- Measured on build 24176760. The three-move route named 900 for "2 + SP" and
-- the game produced 903 - which is the SAME notation in the same catalog, one
-- of the thirteen ambiguous groups Probe D counts. Nineteen of thirty trials
-- came back "move B never appeared; saw action id(s) 903 instead" on a combo
-- that had in fact connected.
--
-- action_id_canonical resolves that group to 900, and it is not wrong: it
-- measured what the button produces from a STANDING character. Which member of
-- a group comes out mid-combo is a different question and nobody has measured
-- it. Accepting the group is what the operator meant - they wrote a notation,
-- and the catalog says these ids are that notation - and it does not pretend
-- the narrower question has been answered.
--
-- Without a catalog the file's id is all there is, which is the honest fallback
-- rather than a reason to refuse.
local function expected_for(route, catalog)
    local out = {}
    for i, s in ipairs(route.steps) do
        -- One implementation, shared with Sweep. Two copies of "which ids count
        -- as this notation" is two chances to answer it differently, and the
        -- answer is the difference between a combo that connected and a row
        -- that says it did not.
        out[i] = Catalog.group_ids(catalog, s.action_id)
    end
    return out
end
M.expected_for = expected_for

local function start_one(delays)
    local key = key_for(delays)
    run.attempts[key] = (run.attempts[key] or 0) + 1
    run.current = delays
    run.current_key = key

    local ok, err = run.injector.start({
        provenance = run.provenance,
        allow_injection = run.allow_injection,
        route = run.route,
        delays = delays,
        expected = expected_for(run.route, run.catalog),
        edge_id = ("%s@%s"):format(tostring(run.route.id), key),
        attempt = run.attempts[key],
        stage_cfg = run.stage_cfg,
        sink = run.sink,
    })
    if not ok then
        run.problems[#run.problems + 1] = { delays = key, reason = tostring(err) }
        return false
    end
    run.started = run.started + 1
    return true
end

-- Driven from the panel's frame callback INSTEAD of Injector.tick, not beside
-- it: a trial in flight owns the frame, and ticking it from two places would
-- advance one trial twice per frame. Same shape as Sweep.tick for the same
-- reason.
--
-- Returns the injector's command when one is in flight, so the caller can see
-- the trial advancing without reaching past this module.
function M.tick()
    if not run or run.done then return end
    local inj = run.injector

    -- A trial in flight owns the frame, and the OUTCOME on the command is the
    -- only thing that says it is over: Injector.running() stays true until
    -- somebody calls stop(). This used to just return inj.tick(), so nothing
    -- ever stopped it and the run sat on combination 1 of 144 forever while
    -- looking exactly like a run in progress. Sweep.tick has always checked the
    -- outcome here; this did not.
    if inj.running() then
        local cmd = inj.tick()
        if cmd and cmd.outcome ~= nil then M.finish_trial() end
        return cmd
    end

    if run.index > #run.grid then
        run.done = true
        run.stopped_because = "every combination was tried"
        return
    end

    start_one(run.grid[run.index])
end

-- Record the finished trial, decide whether its combination was actually
-- tried, and release the injector.
function M.finish_trial()
    if not run then return end
    local inj = run.injector

    if run.current then
        local res = inj.result()
        local trial = res and res.trial

        -- Written through the collector, not through the Injector's sink. The
        -- sink is opened and never used (#45), so a run that trusted it would
        -- record nothing while reporting a path - and "every gap was tried and
        -- none linked" is only worth anything if the gaps are on disk.
        local spec = inj.record and inj.record(nil) or nil
        if spec then
            local rec, problems = ResultCollector.write(run.collector, spec)
            if not rec then
                run.problems[#run.problems + 1] = {
                    delays = run.current_key, reason = "the result would not record",
                    detail = problems and problems[1] and problems[1].problem,
                }
            end
        end

        local verdict = trial and trial.verdict
        if verdict then
            run.by_verdict[verdict] = (run.by_verdict[verdict] or 0) + 1
            if verdict == "link" then
                run.links = run.links + 1
                run.linked_at[#run.linked_at + 1] = run.current_key
            end
        end
        run.finished = run.finished + 1

        -- Retryable means the trial measured nothing, so the combination has
        -- not been tried yet and the index does not move.
        local retry = trial and trial.retryable
            and (run.attempts[run.current_key] or 0) < run.max_attempts
        run.current = nil
        if retry then
            -- left where it is on purpose
        else
            run.index = run.index + 1
        end
        run.current_key = nil
    end
    inj.stop()
end

function M.progress()
    if not run then return nil end
    return {
        route_id = run.route.id,
        index = math.min(run.index, #run.grid),
        total = #run.grid,
        grid_note = run.grid_note,
        started = run.started,
        finished = run.finished,
        links = run.links,
        linked_at = run.linked_at,
        by_verdict = run.by_verdict,
        problems = #run.problems,
        problem_detail = run.problems,
        current = run.current_key,
        done = run.done,
        stopped_because = run.stopped_because,
    }
end

-- The one sentence #48 is asking for.
--
-- "No gap linked" is a real answer and has to read as one, because it is the
-- answer that invalidates every negative in #12's file rather than the answer
-- that says this combo is hard.
function M.verdict()
    local p = M.progress()
    if not p then return nil end
    if p.links > 0 then
        return ("linked at %d of %d gap combination(s): %s")
            :format(p.links, p.finished, table.concat(p.linked_at, ", "))
    end
    if not p.done then
        return ("no gap has linked yet, %d of %d tried"):format(p.finished, p.total)
    end
    return ("NO gap linked, all %d tried - so nothing here shows the pipeline "
        .. "can see a link, and every negative in the sweep is unexplained")
        :format(p.finished)
end

return M
