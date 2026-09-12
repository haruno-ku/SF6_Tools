-- =========================================================
-- ComboExplorer/runtime/Sweep.lua - runs a whole character's worklist, one
-- trial at a time, unattended. Owns the queue and the results file; owns no
-- judgement at all.
-- =========================================================
--
-- WHAT THIS IS FOR
--
-- Start it and walk away. Everything it needs to decide is decided elsewhere:
-- which pairs are worth a trial was settled offline by CandidateGenerator, what
-- a trial means was settled by LinkVerdict, and whether a result is worth
-- keeping was settled by ResultCollector. This file picks the next pair, hands
-- it to the Injector, and puts the answer where it belongs.
--
-- WHY THE PAIRS COME FROM A FILE
--
-- Because the machine running the game does not have what it would take to work
-- them out. install-dev.ps1 syncs only what is under reframework/, and the
-- frame data - the whole reason one pair is worth trying before another - lives
-- at data/frame-data/ on the dev machine. Computing candidates here would mean
-- computing them with no frame data at all: every pair low confidence, no
-- margins, no order.
--
-- So the order is shipped. `tools/lua/explore.lua --worklist` writes a compact
-- list under reframework/data/ComboExplorer_data/worklist/, sorted by
-- confidence, and this reads it. A sweep that is cut short has then spent its
-- time on the pairs the frame data had something to say about.
--
-- WHY IT CHECKS THE CATALOG CHECKSUMS
--
-- A worklist is a list of ACTION IDS, and an action id means nothing except
-- against the catalog it was generated from. Run one against a different build
-- and every pair is about some other move, silently. The checksums are in the
-- worklist for that reason and they are compared before the first trial, not
-- reported afterwards.
--
-- RESUME IS NOT WRITTEN HERE
--
-- core/ResultCollector.lua already does it: JSONL append, an index of what was
-- already run, and a truncated last line treated as "ran but lost the result"
-- rather than as done. This calls claim() and skips what comes back refused.

local ResultCollector = require("func/ComboExplorer/core/ResultCollector")
local Canonical       = require("func/ComboExplorer/core/Canonical")
local Timing          = require("func/ComboExplorer/core/Timing")
local Catalog         = require("func/ComboExplorer/core/Catalog")
local Provenance      = require("func/ComboExplorer/core/Provenance")
local JsonIO          = require("func/ComboExplorer/runtime/JsonIO")

local M = { name = "ComboExplorer.Sweep" }

-- Resolved on first use: the real Injector reaches GameAdapter, which calls sdk
-- at file scope. Tests pass their own.
local _injector = nil
local function default_injector()
    if _injector == nil then
        _injector = require("func/ComboExplorer/runtime/Injector")
    end
    return _injector
end

local run = nil

-- How many times a pair that asked to be retried may come back.
--
-- A retryable outcome is one the trial itself calls inconclusive - the stage
-- failed to reset, the injection gate shut mid-trial - so it deserves another
-- go. It does not deserve unlimited goes: a condition that fails every time
-- would otherwise turn a sweep into an infinite loop over one pair, which looks
-- exactly like a sweep making progress.
M.DEFAULT_MAX_ATTEMPTS = 3

-- How many consecutive failures TO START a trial end the sweep.
--
-- Distinct from a trial that ran and answered nothing. If the Injector will not
-- start - the gate is shut, the profile went away, the sink stopped writing -
-- then nothing is being measured and continuing only burns the operator's
-- evening. Stopping says so.
M.DEFAULT_MAX_START_FAILURES = 5

M.PROVENANCE = {
    max_attempts = "policy: how many times a retryable pair may come back",
    max_start_failures = "policy: consecutive refusals to start before giving up",
}

-- --- the worklist -----------------------------------------------------------

-- Returns the decoded worklist, or nil plus a reason. Separate from start() so
-- a caller can look at one without committing to a sweep.
function M.load_worklist(path, io_)
    io_ = io_ or JsonIO
    if type(path) ~= "string" or path == "" then return nil, "no worklist path" end
    local doc = io_.load(path)
    if type(doc) ~= "table" then
        return nil, ("no worklist at %s - generate one with "
            .. "`lua tools/lua/explore.lua --character <name> --worklist`"):format(path)
    end
    if doc.schema ~= "ce.worklist.v1" then
        return nil, ("%s is not a worklist (schema %s)"):format(path, tostring(doc.schema))
    end
    if type(doc.pairs) ~= "table" or #doc.pairs == 0 then
        return nil, ("%s has no pairs in it"):format(path)
    end
    return doc
end

-- The check that keeps a sweep from being about the wrong moves.
--
-- `catalog` is the one the game actually loaded. Returns true, or false plus a
-- reason naming which half disagrees.
function M.identity_matches(worklist, catalog)
    if type(worklist) ~= "table" or type(catalog) ~= "table" then
        return false, "nothing to compare"
    end
    for _, key in ipairs({ "ac_sha256", "bcm_sha256" }) do
        local want, have = worklist[key], catalog[key]
        if type(want) == "string" and type(have) == "string" and want ~= have then
            return false, ("the worklist was generated against a different catalog: "
                .. "%s is %s there and %s here"):format(key, want:sub(1, 12), have:sub(1, 12))
        end
    end
    return true
end

-- --- starting ----------------------------------------------------------------

-- opts.worklist   : a decoded worklist, or use opts.path
-- opts.catalog    : the live catalog, for the identity check
-- opts.collector  : a ResultCollector. Required - a sweep that cannot record is
--                   a sweep that did not happen
-- opts.provenance : the register, passed through to every trial
-- opts.injector   : substituted by tests
-- opts.delay      : ticks between A and B, one value for this pass
-- opts.delays     : one per gap, for a route with more than one. Either form is
--                   accepted and BOTH are used - this used to store `delays` and
--                   then read only `delay`, so a caller that passed a list got a
--                   sweep that ran at nil delay and skipped every pair while
--                   reporting itself finished
function M.start(opts)
    opts = opts or {}
    if run then return nil, "a sweep is already running" end

    local worklist = opts.worklist
    if worklist == nil and opts.path then
        local wl, werr = M.load_worklist(opts.path)
        if not wl then return nil, werr end
        worklist = wl
    end
    if type(worklist) ~= "table" then return nil, "no worklist" end

    if opts.catalog then
        local ok, why = M.identity_matches(worklist, opts.catalog)
        if not ok then return nil, why end
    end

    if type(opts.collector) ~= "table" then
        return nil, "no collector - a sweep that cannot record is a sweep that did not happen"
    end

    -- Refused rather than defaulted, and the failure it prevents is the nastiest
    -- kind available here. The delay is part of a trial's identity, so with none
    -- the collector cannot build a key, every claim comes back refused, every
    -- pair is counted as skipped, and the sweep reports itself FINISHED having
    -- pressed nothing. A night that looks like a completed pass and contains no
    -- measurements is worse than one that stopped at the first pair.
    --
    -- SequenceCompiler refuses an absent delay for the same reason and says it
    -- in its own header: "a default would be a guess, and a guess that produces
    -- a working-looking program is the worst kind".
    if type(opts.delay) ~= "number" and type(opts.delays) ~= "table" then
        return nil, "no delay - how long to wait between the two moves is what a "
            .. "sweep measures, and without it every trial would be skipped and "
            .. "the sweep would report itself finished having pressed nothing"
    end

    -- The worklist names action ids the CATALOG chose within a notation group;
    -- the register knows which of them the button actually produces on this
    -- build. Applied here, once, before the first trial - see
    -- core/Canonical.lua for why it is not applied when the worklist is
    -- generated, and for the 148 pairs that could not have succeeded without
    -- it.
    --
    -- Failure is not fatal on its own: an operator may be sweeping before the
    -- calibration has run, and a sweep against the shipped ids is still a
    -- sweep. What must not happen is it being silent, so the reason rides on
    -- the run and the panel prints it.
    local canonical, cwhy = nil, nil
    if opts.provenance then
        canonical, cwhy = Provenance.value(opts.provenance, "action_id_canonical")
    else
        cwhy = "no provenance register was given"
    end

    local creport = nil
    if canonical then
        local folded, rep = Canonical.apply(worklist, canonical)
        if folded then
            worklist, creport = folded, rep
        else
            cwhy = tostring(rep)
        end
    end

    run = {
        injector = opts.injector or default_injector(),
        worklist = worklist,
        -- Passed straight through to every Injector.start. Sweep owns no
        -- judgement about the stage; it only has to hand every trial the same
        -- one, because a sweep whose trials ran under different setups is not
        -- one dataset.
        stage_cfg = opts.stage_cfg,
        -- For Catalog.group_ids as well as the identity check.
        catalog = opts.catalog,
        -- For Timing. The buffer is unverified, and the sweep is allowed to use
        -- the guess for the same reason the calibration sweep is: it is testing
        -- the window, not trusting it.
        buffer_ticks = opts.buffer_ticks,
        hold_ticks = opts.hold_ticks,
        canonical_report = creport,
        canonical_why = (creport == nil) and tostring(cwhy or "unavailable") or nil,
        collector = opts.collector,
        provenance = opts.provenance,
        delay = opts.delay,
        delays = opts.delays,
        allow_injection = opts.allow_injection,
        sink = opts.sink,

        max_attempts = opts.max_attempts or M.DEFAULT_MAX_ATTEMPTS,
        max_start_failures = opts.max_start_failures or M.DEFAULT_MAX_START_FAILURES,

        index = 1,              -- where in worklist.pairs we are
        requeued = {},          -- pairs asking for another go, taken after the list
        attempts = {},          -- key -> how many times it has been tried
        started = 0,
        finished = 0,
        skipped = 0,
        start_failures = 0,
        consecutive_start_failures = 0,
        problems = {},
        done = false,
        stopped_because = nil,
    }
    return true
end

function M.stop() run = nil end
function M.running() return run ~= nil end

-- --- the queue ---------------------------------------------------------------

local function pair_key(p)
    return ("%d:%s->%d:%s"):format(p.a_id, tostring(p.a_method), p.b_id, tostring(p.b_method))
end

-- The next pair to try, or nil when there is nothing left. Requeued pairs come
-- AFTER the whole list rather than immediately: whatever made one inconclusive
-- is more likely to have passed by the time the list has been round once.
local function next_pair()
    local p = run.worklist.pairs[run.index]
    if p ~= nil then
        run.index = run.index + 1
        return p
    end
    return table.remove(run.requeued, 1)
end

local function route_for(p)
    return {
        id = ("s-%d-%d"):format(p.a_id, p.b_id),
        character = run.worklist.character,
        control_scheme = run.worklist.control_scheme,
        steps = {
            { index = 1, action_id = p.a_id, input_method = p.a_method,
              notation = p.a_notation },
            { index = 2, action_id = p.b_id, input_method = p.b_method,
              notation = p.b_notation },
        },
    }
end

-- --- one frame ---------------------------------------------------------------

-- Driven from Clock.on_frame beside the other machines. Returns whatever the
-- Injector's tick returned, or nil on a frame where nothing was driven.
-- The gap this pair is run at, and where it came from.
--
-- Separate and public so a caller can see what the sweep would do before it
-- does it, and so the fallback is visible rather than a number appearing from
-- nowhere.
function M.delay_for(p, r)
    r = r or run or {}
    local a = { startup = p.a_startup, active = p.a_active, recovery = p.a_recovery,
                hitstop = p.a_hitstop, hitstun = p.a_hitstun }
    local b = { startup = p.b_startup }
    local w, missing = Timing.window(a, b, {
        hold_ticks = r.hold_ticks or 3,
        buffer_ticks = r.buffer_ticks,
    })
    if w then return w.latest, { predicted = true, window = w } end

    -- No window. The pair still runs, at whatever the operator set, and the row
    -- says the gap was NOT predicted - a negative measured at an unpredicted
    -- gap is not evidence that the pair does not link.
    -- What it actually saw, not only what it wanted. "missing: a.recovery" and
    -- "missing: nothing, and still no window" send an operator to different
    -- places, and the first run of this printed "no reason given" - which sent
    -- me guessing at the code instead of reading the data.
    local saw = ("startup=%s active=%s recovery=%s hitstop=%s b=%s buffer=%s"):format(
        tostring(p.a_startup), tostring(p.a_active), tostring(p.a_recovery),
        tostring(p.a_hitstop), tostring(p.b_startup), tostring(r.buffer_ticks))
    return r.delay, { predicted = false, missing = missing, saw = saw }
end

function M.tick()
    if not run or run.done then return nil end
    local inj = run.injector

    -- A trial in flight owns the frame.
    if inj.running() then
        local cmd = inj.tick()
        if cmd and cmd.outcome ~= nil then M.finish_trial() end
        return cmd
    end

    -- Otherwise start the next one.
    local p = next_pair()
    if p == nil then
        run.done = true
        run.stopped_because = "the worklist is finished"
        return nil
    end

    -- WHEN to press the second move, from the frames the worklist now carries.
    --
    -- This used to be run.delay for every pair - 4, because that is the panel's
    -- default and nothing else was available. At gap 4 the second input lands
    -- inside the first move's animation: a cancel window. Measured on build
    -- 24176760, one real pair's LINK window was gap 40..44, and the sweep's 202
    -- rows found 8 links, all of them Super Arts, which are the only thing that
    -- connects out of a cancel window (#46).
    --
    -- `latest` rather than the middle of the window: it is the gap at which A
    -- has just become free, which is the one the frame data states directly.
    -- The earlier end depends on the input buffer, which is unverified.
    -- gap_why, not `why`: this function already has a `why` from
    -- ResultCollector.claim below, and naming this one the same shadowed it.
    -- The claim's why is nil on success, so every predicted gap was counted as
    -- a fallback while the predicted delay was being used - the sweep said
    -- "0 predicted" and pressed at 69 anyway.
    local delay, gap_why = M.delay_for(p, run)
    local key = pair_key(p)
    -- ResultCollector.delay_list accepts a number or a list, so whichever form
    -- the caller gave is handed through unchanged. Reading `run.delay` alone
    -- here was the bug: with a list supplied, this key was built from nil, the
    -- claim was refused, and the pair counted as skipped.
    local spec_for_claim = {
        edge_id = key, attempt = (run.attempts[key] or 0) + 1,
        delay = run.delays or delay,
    }
    -- Skipping is the collector's decision, not this file's: it is the one that
    -- read the previous run's file and knows what is already answered.
    local may, why = ResultCollector.claim(run.collector, spec_for_claim)
    if not may then
        run.skipped = run.skipped + 1
        run.last_skip = ("%s: %s"):format(key, tostring(why))
        return nil
    end

    if gap_why and gap_why.predicted then
        run.predicted = (run.predicted or 0) + 1
    else
        run.unpredicted = (run.unpredicted or 0) + 1
        -- WHICH field was missing, kept for the panel. "0 predicted" with no
        -- reason is a number an operator can only guess at, and guessing at it
        -- is what this whole suite is built to avoid.
        run.unpredicted_why = ((gap_why and gap_why.missing
            and table.concat(gap_why.missing, ", ")) or "nothing named")
            .. "  |  " .. tostring(gap_why and gap_why.saw)
    end
    run.attempts[key] = (run.attempts[key] or 0) + 1
    run.current = p
    run.current_key = key

    local ok, err = inj.start({
        provenance = run.provenance,
        allow_injection = run.allow_injection,
        route = route_for(p),
        delay = delay,
        delays = run.delays,
        -- The whole notation group, not the one id the worklist names. See
        -- Catalog.group_ids: 105 of this sweep's 216 rows came back "saw action
        -- id(s) N instead" on the OTHER member of the same group.
        expected = {
            [1] = Catalog.group_ids(run.catalog, p.a_id),
            [2] = Catalog.group_ids(run.catalog, p.b_id),
        },
        edge_id = key,
        attempt = run.attempts[key],
        sink = run.sink,
        -- The same override every trial in this sweep runs under. It also
        -- scopes the resume, through Injector.conditions_for: a pair answered
        -- with the fighters 300 apart has not been answered with them in
        -- range, and skipping it as done would be the sweep believing a
        -- whiffed trial.
        stage_cfg = run.stage_cfg,
    })

    if not ok then
        run.start_failures = run.start_failures + 1
        run.consecutive_start_failures = run.consecutive_start_failures + 1
        run.problems[#run.problems + 1] = { pair = key, reason = tostring(err) }
        -- Nothing is being measured. Continuing only burns the evening.
        if run.consecutive_start_failures >= run.max_start_failures then
            run.done = true
            run.stopped_because = ("%d trials in a row would not start - last reason: %s")
                :format(run.consecutive_start_failures, tostring(err))
        end
        return nil
    end

    run.consecutive_start_failures = 0
    run.started = run.started + 1
    return nil
end

-- Record the finished trial and decide whether its pair comes back.
--
-- Separate from tick() so a test can drive it directly, and because the two
-- decisions in it - what to record, and what to retry - are the only judgement
-- this file makes.
function M.finish_trial()
    if not run then return nil, "no sweep" end
    local inj = run.injector
    local result = inj.result()
    local key = run.current_key

    local spec = inj.record(nil)   -- the spec, not yet written
    if spec then
        local rec, problems = ResultCollector.write(run.collector, spec)
        if not rec then
            run.problems[#run.problems + 1] = {
                pair = key, reason = "the result would not record",
                detail = problems and problems[1] and problems[1].problem,
            }
        end
    end

    -- A trial that answered nothing may come back, up to a bound. `retryable`
    -- is the runner's own word for it - a stage that failed to reset, a gate
    -- that shut mid-trial - and it is deliberately not re-derived here.
    local trial = result and result.trial
    if trial and trial.retryable and run.current then
        if (run.attempts[key] or 0) < run.max_attempts then
            run.requeued[#run.requeued + 1] = run.current
        else
            run.problems[#run.problems + 1] = {
                pair = key,
                reason = ("gave up after %d attempts"):format(run.max_attempts),
            }
        end
    end

    run.finished = run.finished + 1
    run.current, run.current_key = nil, nil
    inj.stop()
    return true
end

-- --- readouts ----------------------------------------------------------------

function M.progress()
    if not run then return nil end
    local total = #run.worklist.pairs
    return {
        character = run.worklist.character,
        index = math.min(run.index - 1, total),
        total = total,
        requeued = #run.requeued,
        started = run.started,
        finished = run.finished,
        skipped = run.skipped,
        start_failures = run.start_failures,
        problems = #run.problems,
        done = run.done,
        stopped_because = run.stopped_because,
        current = run.current_key,
        last_skip = run.last_skip,
        -- What the register did to this list. Shown while it runs, because
        -- "230 / 230" against a 378-pair file needs its reason next to it or it
        -- reads as a truncated worklist.
        canonical = run.canonical_report
            and Canonical.summary(run.canonical_report) or nil,
        canonical_why = run.canonical_why,
        -- How many gaps came from the frame data and how many fell back.
        -- A run that is mostly fallback is a run measuring the wrong
        -- thing, and it should be visible while it happens.
        predicted = run.predicted or 0,
        unpredicted = run.unpredicted or 0,
        unpredicted_why = run.unpredicted_why,
    }
end

function M.result()
    if not run then return nil end
    local p = M.progress()
    p.summary = ResultCollector.summary(run.collector)
    p.problem_detail = run.problems
    return p
end

return M
