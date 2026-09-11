-- =========================================================
-- ComboExplorer/core/ConfirmedEdge.lua - turns a pile of trials into one
-- statement per pair. Pure: decoded trial records in, ce.confirmed_edge.v1 out.
-- =========================================================
--
-- THE LINK THAT WAS MISSING
--
-- The sweep writes one ce.trial.v1 per attempt and stops there. Schema has had
-- ce.confirmed_edge.v1 and ce.verified_combo.v1 defined, with validators, since
-- the beginning, and NOTHING produced either - so "run the sweep and you get a
-- list of combos that work" was not true. You got a list of attempts.
--
-- This is the first half of that: attempts -> one answer per pair.
--
-- WHAT A SINGLE TRIAL IS NOT
--
-- Stable. One attempt that linked is one attempt that linked; it is not a
-- reproduction, and calling it one would put every one-off fluke into the
-- published list with the same standing as a link that came out ten times.
--
-- Schema already refuses a verified edge that is neither `stable` nor
-- `unstable_ok` - the second being the caller saying "I know, and I mean it".
-- So a single positive trial produces a VERIFIED edge that is honestly marked
-- unstable, and the report says how many of those there are. What it does not
-- do is quietly promote it.
--
-- UNANSWERED IS NOT NEGATIVE
--
-- a_failed, wrong_move and inconclusive mean the trial ran and answered nothing
-- about the link. They are counted as attempts - the time was spent - and they
-- are NOT counted as failures. A pair whose every trial was unanswered comes
-- out `runtime_pending`, which is the truth: still an open question.
--
-- Treating those as negatives is the one failure this whole project is built to
-- avoid, and it would be very easy here: `successes < attempts` looks like a
-- reasonable test for "did not work" and is wrong.
--
-- ONE COHORT AT A TIME
--
-- Trials only fold together when they are evidence about the SAME experiment:
-- same build, same calibration, same character and scheme, same conditions.
-- This used to group on edge_id alone and take the first record's provenance,
-- which #38 named as a risk against this function by name.
--
-- It is not theoretical. Redoing the calibration in the middle of a session
-- changes calibration_id, so one evening's log can hold two cohorts without
-- anybody doing anything unusual - and folding them together would average two
-- experiments into one number with no sign that it happened.
--
-- Records from another cohort are not dropped. They are folded into their own
-- edge, because throwing measurements away and inventing one are both worse
-- than reporting two.
--
-- DELAY IS THE POINT, NOT A DETAIL
--
-- Trials at different delays are different experiments on the same pair. Which
-- delays linked IS the execution window - the `execution_leniency_frames` that
-- core/Scoring.lua refuses to predict because "how many frames wide the window
-- is can only be measured by sweeping it on the real game". So the per-delay
-- breakdown is kept on every edge, and the widest run of consecutive linking
-- delays is reported as what was actually measured.

local Schema = require("func/ComboExplorer/core/Schema")
local ResultCollector = require("func/ComboExplorer/core/ResultCollector")

local M = { name = "ComboExplorer.ConfirmedEdge" }

M.KIND = Schema.KIND.CONFIRMED

-- How many conclusive attempts at one delay before a result may call itself
-- reproduced.
--
-- Two, not three: two agreeing attempts is the smallest claim that is not "it
-- happened once". Three is better and the caller can ask for it; baking three
-- in would mean a first pass produces nothing stable at all, and a first pass
-- producing nothing is how a tool stops being used.
M.DEFAULT_MIN_ATTEMPTS = 2

-- --- reading one trial --------------------------------------------------------

-- What this trial said about the link, or nil plus a reason.
--
-- Goes through ResultCollector.classify rather than testing the verdict string,
-- so a verdict added upstream and not taught to that module is refused here too
-- instead of being absorbed as whatever this file's else-branch happens to be.
local function meaning_of(rec)
    if type(rec) ~= "table" then return nil, "not a record" end
    if rec.schema ~= Schema.KIND.TRIAL then
        return nil, ("not a trial record (schema %s)"):format(tostring(rec.schema))
    end
    if type(rec.edge_id) ~= "string" or rec.edge_id == "" then
        return nil, "a trial with no edge_id says nothing about any pair"
    end
    return ResultCollector.classify(rec.verdict)
end

local function delay_key(rec)
    local key = ResultCollector.delay_key(rec.delays or rec.delay)
    return key or "?"
end

-- --- the widest measured window -----------------------------------------------

-- The longest run of CONSECUTIVE delays that linked, given the delays that were
-- actually tried. Returns the run and the delays it rests on.
--
-- "Consecutive" is over the tried values, not over the integers: a sweep that
-- tried 2, 4 and 6 and linked at all three has measured three points, not a
-- five-frame window. Claiming the gap would be inventing the trials nobody ran.
function M.window(by_delay)
    local tried = {}
    for key, d in pairs(by_delay or {}) do
        local n = tonumber(key)
        if n ~= nil then tried[#tried + 1] = { delay = n, linked = d.successes > 0 } end
    end
    if #tried == 0 then return nil end
    table.sort(tried, function(a, b) return a.delay < b.delay end)

    local best, run = nil, nil
    for i = 1, #tried do
        if tried[i].linked then
            if run == nil then run = { from = tried[i].delay, to = tried[i].delay, count = 1 }
            else run.to = tried[i].delay run.count = run.count + 1 end
            if best == nil or run.count > best.count then
                best = { from = run.from, to = run.to, count = run.count }
            end
        else
            run = nil
        end
    end
    if best == nil then return nil end

    best.contiguous_over_tried_values = true
    best.tried_count = #tried
    return best
end

-- --- one pair ------------------------------------------------------------------

-- trials : every record for ONE edge_id
-- Returns a ce.confirmed_edge.v1, or nil plus a reason.
function M.fold(trials, opts)
    opts = opts or {}
    if type(trials) ~= "table" or #trials == 0 then return nil, "no trials" end

    local min_attempts = opts.min_attempts or M.DEFAULT_MIN_ATTEMPTS
    local edge_id = trials[1].edge_id
    local cohort_key = ResultCollector.cohort_key(trials[1])

    local attempts, successes, negatives, unanswered = 0, 0, 0, 0
    local by_delay = {}
    local verdicts = {}
    local first_at, last_at = nil, nil
    local provenance = nil

    for _, rec in ipairs(trials) do
        local m, why = meaning_of(rec)
        if not m then return nil, why end
        if rec.edge_id ~= edge_id then
            return nil, ("fold was given trials for two different pairs: %s and %s")
                :format(tostring(edge_id), tostring(rec.edge_id))
        end
        -- Same refusal, one level up. Two trials of the same pair measured
        -- under different conditions are two results, and a function that
        -- returns one answer must not be handed both.
        local this_cohort = ResultCollector.cohort_key(rec)
        if this_cohort ~= cohort_key then
            return nil, ("fold was given trials from two different cohorts: %s and %s")
                :format(cohort_key, this_cohort)
        end

        attempts = attempts + 1
        verdicts[rec.verdict] = (verdicts[rec.verdict] or 0) + 1

        local key = delay_key(rec)
        local d = by_delay[key]
        if not d then d = { attempts = 0, successes = 0, negatives = 0, unanswered = 0 }
                      by_delay[key] = d end
        d.attempts = d.attempts + 1

        if m == ResultCollector.ANSWERS.POSITIVE then
            successes = successes + 1
            d.successes = d.successes + 1
        elseif m == ResultCollector.ANSWERS.NEGATIVE then
            negatives = negatives + 1
            d.negatives = d.negatives + 1
        else
            unanswered = unanswered + 1
            d.unanswered = d.unanswered + 1
        end

        provenance = provenance or rec.provenance
        local at = rec.recorded_at
        if type(at) == "string" then
            if first_at == nil or at < first_at then first_at = at end
            if last_at == nil or at > last_at then last_at = at end
        end
    end

    -- The status, decided on what was ANSWERED.
    --
    -- `unanswered` is deliberately absent from every branch below except the
    -- last. A trial that answered nothing is time spent, not evidence, and
    -- `successes < attempts` - which reads like a fair test for "did not work" -
    -- would turn a pair nobody could set up into a pair that does not link.
    local answered = successes + negatives
    local status, stable, reason

    if answered == 0 then
        status = Schema.STATUS.RUNTIME_PENDING
        stable = false
        reason = ("%d attempt(s), none of which answered the question"):format(attempts)
    elseif successes > 0 and negatives == 0 then
        status = Schema.STATUS.VERIFIED
        -- Reproduced means: enough conclusive attempts AT ONE DELAY, all
        -- agreeing. Counting across delays would call a pair stable because it
        -- linked once at 4 and once at 5, which is two experiments each run
        -- once.
        stable = false
        for _, d in pairs(by_delay) do
            if d.successes >= min_attempts and d.negatives == 0 then stable = true end
        end
        reason = stable
            and ("linked in %d of %d attempts, reproduced at a single delay"):format(successes, attempts)
            or ("linked in %d of %d attempts, but never twice at the same delay")
                :format(successes, attempts)
    elseif successes == 0 then
        status = Schema.STATUS.REJECTED
        stable = (negatives >= min_attempts)
        reason = ("%d conclusive attempt(s), none of which linked"):format(negatives)
    else
        -- Both. Usually the delay window: it links at some delays and not
        -- others, which is the measurement rather than a contradiction.
        status = Schema.STATUS.VERIFIED
        stable = false
        for _, d in pairs(by_delay) do
            if d.successes >= min_attempts and d.negatives == 0 then stable = true end
        end
        reason = ("linked at some delays and not others: %d of %d conclusive attempts linked")
            :format(successes, answered)
    end

    local edge = {
        schema = M.KIND,
        -- The cohort is part of the id because it is part of the claim. Two
        -- rows for one pair under different conditions are two different
        -- statements, and an id that could not tell them apart would let a
        -- later reader - or a database key - keep only one of them.
        id = ("confirmed %s @ %s"):format(tostring(edge_id),
                                          ResultCollector.cohort_tag(trials[1])),
        edge_id = edge_id,
        cohort_key = cohort_key,
        cohort = ResultCollector.identity_of(trials[1]),
        status = status,
        attempts = attempts,
        successes = successes,
        negatives = negatives,
        unanswered = unanswered,
        stable = stable,
        by_delay = by_delay,
        verdicts = verdicts,
        window = M.window(by_delay),
        reason = reason,
        first_recorded_at = first_at,
        last_recorded_at = last_at,
        provenance = provenance,
    }

    -- Schema demands these on anything verified or rejected, and they are true
    -- of every row here: each one rests on trials that ran on the game.
    if status == Schema.STATUS.VERIFIED or status == Schema.STATUS.REJECTED then
        edge.runtime_verified = true
        edge.evidence = {
            attempts = attempts, successes = successes,
            negatives = negatives, unanswered = unanswered,
            by_delay = by_delay,
        }
    else
        edge.runtime_verified = false
    end

    -- The caller's deliberate override, carried only when it was given. An edge
    -- that is verified and not stable is refused by the schema unless somebody
    -- says they know - so this is how they say it, and it stays visible.
    if opts.unstable_ok and status == Schema.STATUS.VERIFIED and not stable then
        edge.unstable_ok = true
    end

    return edge
end

-- --- the whole log ---------------------------------------------------------------

-- records : decoded ce.trial.v1 records, in any order
--
-- Returns edges (sorted by edge_id then cohort), problems, counts, cohorts.
-- Nothing is dropped silently: a record this cannot read goes to `problems`
-- with its reason, and a log holding more than one cohort produces more than
-- one edge per pair rather than one averaged over both.
function M.from_trials(records, opts)
    opts = opts or {}
    local groups, order = {}, {}
    local problems = {}
    local cohorts, cohort_order = {}, {}

    for i, rec in ipairs(records or {}) do
        local m, why = meaning_of(rec)
        if not m then
            problems[#problems + 1] = { record = i, reason = why }
        else
            -- The pair AND the experiment. Grouping on the pair alone is what
            -- #38 warns about: it averages two experiments into one number with
            -- nothing in the output to say it happened.
            local cohort_key = ResultCollector.cohort_key(rec)
            local key = rec.edge_id .. "\n" .. cohort_key
            local g = groups[key]
            if not g then
                g = {}
                groups[key] = g
                order[#order + 1] = { key = key, edge_id = rec.edge_id, cohort = cohort_key }
            end
            g[#g + 1] = rec

            local c = cohorts[cohort_key]
            if not c then
                c = { key = cohort_key, identity = ResultCollector.identity_of(rec),
                      trials = 0, edges = 0 }
                cohorts[cohort_key] = c
                cohort_order[#cohort_order + 1] = c
            end
            c.trials = c.trials + 1
        end
    end

    -- Sorted on both halves, so two runs over the same log produce the same
    -- file whichever order the lines were written in.
    table.sort(order, function(a, b)
        if a.edge_id ~= b.edge_id then return a.edge_id < b.edge_id end
        return a.cohort < b.cohort
    end)
    table.sort(cohort_order, function(a, b) return a.key < b.key end)

    local edges = {}
    for _, g in ipairs(order) do
        local edge, why = M.fold(groups[g.key], opts)
        if edge then
            edges[#edges + 1] = edge
            cohorts[g.cohort].edges = cohorts[g.cohort].edges + 1
        else
            problems[#problems + 1] = { edge_id = g.edge_id, cohort = g.cohort, reason = why }
        end
    end

    local counts = { edges = #edges, trials = #(records or {}), problems = #problems,
                     cohorts = #cohort_order,
                     verified = 0, rejected = 0, pending = 0, stable = 0 }
    for _, e in ipairs(edges) do
        if e.status == Schema.STATUS.VERIFIED then counts.verified = counts.verified + 1
        elseif e.status == Schema.STATUS.REJECTED then counts.rejected = counts.rejected + 1
        else counts.pending = counts.pending + 1 end
        if e.stable then counts.stable = counts.stable + 1 end
    end

    return edges, problems, counts, cohort_order
end

return M
