-- =========================================================
-- tools/lua/labeval.lua - lab runs in, evaluations out (#38 section 8, Phase B).
-- Pure: tables in, tables out. No files, no json, no hashing, no SQL.
-- =========================================================
--
-- WHAT AN EVALUATION IS
--
-- One statement about one subject in one cohort, under one policy: "under
-- ce-eval-v1, pair 611:manual->1206:manual, measured with calibration X on patch
-- Y under conditions Z, was reproduced, on these runs, leaving out those runs
-- for these reasons". The runs are never touched. An evaluation says which of
-- them it counted and why it left the others out, and a different policy over
-- the same runs is a different evaluation next to this one, not a correction
-- of it (#38: 評価ルール更新時はevaluationを新規生成。古い評価と元runを保持する).
--
-- The input is the rows tools/lua/labrows.lua builds, one per distinct
-- observation (the importer has already merged identical lines), each with its
-- event_key and the run_sources locations it was found at. A run's flags are
-- the union of its own and every location's - the same set the lab.run_quality
-- view reads - because a flag that one file knows about is true of the
-- observation wherever else it was committed.
--
-- WHO DECIDES WHAT
--
-- Nothing here re-derives a rule another module owns:
--   the cohort          ResultCollector.cohort_key, the key ConfirmedEdge folds by
--   a pair's stability  ConfirmedEdge.fold (>= min_attempts links at ONE delay,
--                       no negatives there), and its window
--   a route's status    SweepReport.combo_status (>= CONFIRM_LINKS links at any
--                       gap), the rule the combo page prints
--   what a flag means   tools/lua/labrows.lua, which sets them
-- What this module adds is the one thing none of them had: which runs COUNT.
--
-- Hashing and ids stay in tools/db/lab-eval.mjs, like every other hash in the
-- import (node:crypto, one implementation). This module produces the text the
-- evidence_set_hash is taken over, sorted, so that text is what the tests pin.
--
-- ---------------------------------------------------------------------------
-- POLICY ce-eval-v1, AND WHY EACH RULE IS WHAT IT IS
--
-- The rules are data (M.POLICIES), stored whole in lab.evaluation_policies.rules,
-- so a reader of the database sees the rule an evaluation was made under
-- without this file. Every flag labrows can set must be named by the policy
-- exactly once; a flag the policy does not mention is a refusal, not a pass,
-- because a new flag exists precisely to say something about the runs.
--
-- 1. superseded_rerun excludes the run, whatever it answered.
--    The file was re-run with a defect fixed and the re-run holds the same key
--    in the same cohort (0370f6c for framedata-singleid, 9a1cea9 / 8c7e9f2 for
--    the ground-truth pre-group file). Counting both would count one question
--    twice, once with the defect. The re-run is the answer.
--
-- 2. A POSITIVE counts unless rule 1 excluded it.
--    A link is the game saying the combo connected: the timing it was pressed
--    at being late (be1c0be), the gap being a cancel window (#46), or today's
--    compiler judging the input unpressable (#49) do not undo a link that was
--    observed. If anything, a link under a handicap is stronger evidence.
--
-- 3. A NEGATIVE counts as a conclusive failure only with none of:
--      fixed_delay_4               every pair at gap 4, inside A's animation: a
--                                  cancel window, not a link window (#46, 1e2eb5b).
--                                  Its whiffs never asked whether a pair links.
--      unplayable_input            SequenceCompiler.unplayable would not press it
--                                  today (#49): a whiff means the input did not
--                                  come out as written, not that the pair fails.
--      link_timing_on_cancel_pair  a cancel-only pair pressed at the LINK gap,
--                                  after A recovered, where no cancel exists (be1c0be).
--      motion_button_late          B's button came motion_ticks after the recorded
--                                  delay (be1c0be): the question was asked late.
--    Otherwise the negative is EXCLUDED with the first of those flags, in that
--    order, as its reason: from "the experiment asked a different question" to
--    "it asked this question late".
--
-- 4. An UNANSWERED run counts as unanswered unless rule 1 excluded it.
--    It answered nothing either way, so there is nothing for rule 3 to take
--    away, and hiding it would hide the time spent. evidence_missing (b5f67bc:
--    before it, an unanswered trial lost its evidence) changes WHY it is
--    unanswered, not whether.
--
-- 5. legacy_route_subject never excludes.
--    The row was written as a fake edge before a route could be a subject
--    (#14, e0e9f88); labrows has already read it as the route it was about, so
--    the subject is resolved and the observation is as good as a new one.
--
-- Every excluded run is still listed in evaluation_runs, with its reason.
--
-- ---------------------------------------------------------------------------
-- SUBJECTS AND COHORTS
--
-- pair  (subject_kind edge, test_kind pair_link): subject = the edge key
--       "611:manual->1206:manual". The counted runs of one cohort are handed to
--       ConfirmedEdge.fold as trial records rebuilt from the row (the cohort key
--       reads conditions through TestContext.key, which takes the canonical
--       string the row carries, so the key is the one the record itself gives).
-- route (subject_kind route, test_kind full_combo): subject = the route id
--       ("zangief-assist-ground-truth"). Counted links are handed to
--       SweepReport.combo_status.
--
-- Both are evaluated per cohort (ResultCollector.cohort_key: patch, calibration,
-- character, scheme, conditions). Two cohorts are two evaluations, never one
-- averaged over both (#38 section 8, d867421).
--
-- ---------------------------------------------------------------------------
-- RESULT (checked in this order)
--
--   pending              no counted run answered (successes + failures = 0)
--   reproduced           pair: ConfirmedEdge says stable (and it linked);
--                        route: SweepReport.combo_status says confirmed (>= 2
--                        counted links at any gap)
--   mixed                counted links AND counted failures, not reproduced.
--                        For a pair this is usually the timing window - it links
--                        at some delays and not others - which by_delay and
--                        window show; it is a measurement, not a contradiction
--   observed_success     counted links, no counted failures, not reproduced
--                        (one link, or links never twice at one delay)
--   no_success_observed  counted failures and no link. A fact about the delays
--                        that were tried, not "this cannot connect" (#38)
--
-- A pair can be reproduced with failures beside it: stable at one delay, whiffs
-- at another. That is the window, and measured_summary carries it.

local ConfirmedEdge   = require("func/ComboExplorer/core/ConfirmedEdge")
local ResultCollector = require("func/ComboExplorer/core/ResultCollector")
local Schema          = require("func/ComboExplorer/core/Schema")
local SweepReport     = dofile("tools/lua/sweepreport.lua")
local LabRows         = dofile("tools/lua/labrows.lua")

local M = { name = "tools.labeval" }

local FLAG = LabRows.FLAG

M.RESULT = {
    PENDING             = "pending",
    OBSERVED_SUCCESS    = "observed_success",
    REPRODUCED          = "reproduced",
    MIXED               = "mixed",
    NO_SUCCESS_OBSERVED = "no_success_observed",
}

M.INCLUSION = { COUNTED = "counted", EXCLUDED = "excluded" }

M.SUBJECT = { EDGE = "edge", ROUTE = "route" }

local ANSWERS = ResultCollector.ANSWERS

M.POLICIES = {
    ["ce-eval-v1"] = {
        key = "ce-eval-v1",
        version = 1,
        description = "Superseded re-runs are left out entirely. A link counts "
            .. "unless superseded. A negative counts only when the run asked the "
            .. "question at the right timing with a pressable input "
            .. "(no fixed_delay_4, unplayable_input, link_timing_on_cancel_pair, "
            .. "motion_button_late). Unanswered runs count as unanswered. Pairs fold "
            .. "per cohort through ConfirmedEdge (reproduced = stable); routes per "
            .. "cohort through the combo rule (reproduced = 2 counted links at any gap).",
        rules = {
            labrows_version = LabRows.VERSION,
            -- Rule 1: left out whatever the run answered.
            exclude_run = { FLAG.SUPERSEDED_RERUN },
            -- Rule 3: a negative with any of these is left out; the first one
            -- present, in this order, is the reason recorded.
            exclude_negative = {
                FLAG.FIXED_DELAY_4,
                FLAG.UNPLAYABLE_INPUT,
                FLAG.LINK_TIMING_ON_CANCEL_PAIR,
                FLAG.MOTION_BUTTON_LATE,
            },
            -- Rules 4 and 5: named so that "not excluding" is a decision too.
            never_exclude = { FLAG.LEGACY_ROUTE_SUBJECT, FLAG.EVIDENCE_MISSING },
            positive = "counted unless exclude_run",
            unanswered = "counted as unanswered unless exclude_run",
            cohort = "ResultCollector.cohort_key",
            pair = { subject_kind = "edge", fold = "ConfirmedEdge.fold",
                     min_attempts = ConfirmedEdge.DEFAULT_MIN_ATTEMPTS,
                     reproduced = "stable" },
            route = { subject_kind = "route", rule = "SweepReport.combo_status",
                      confirm_links = SweepReport.CONFIRM_LINKS,
                      reproduced = "confirmed" },
            result_order = { "pending", "reproduced", "mixed", "observed_success",
                             "no_success_observed" },
        },
    },
}

M.DEFAULT_POLICY = "ce-eval-v1"

-- --- the policy --------------------------------------------------------------------

-- Returns true, or false and the problems. Refuses a policy that leaves a flag
-- unclassified or names one twice, and a route rule whose number is not the one
-- SweepReport actually applies - rules stored as data that the code does not
-- follow would be a record of a rule nobody used.
function M.check_policy(policy)
    local problems = {}
    if type(policy) ~= "table" or type(policy.rules) ~= "table" then
        return false, { "not a policy" }
    end
    local r = policy.rules
    local seen = {}
    for _, list_name in ipairs({ "exclude_run", "exclude_negative", "never_exclude" }) do
        for _, f in ipairs(r[list_name] or {}) do
            if seen[f] then
                problems[#problems + 1] = ("flag %s is named by both %s and %s"):format(f, seen[f], list_name)
            end
            seen[f] = list_name
        end
    end
    local known = {}
    for _, f in pairs(FLAG) do
        known[f] = true
        if not seen[f] then
            problems[#problems + 1] = ("the policy does not say what flag %s means"):format(f)
        end
    end
    for f in pairs(seen) do
        if not known[f] then
            problems[#problems + 1] = ("the policy names flag %s, which labrows does not set"):format(f)
        end
    end
    if type(r.route) ~= "table" or r.route.confirm_links ~= SweepReport.CONFIRM_LINKS then
        problems[#problems + 1] = ("route.confirm_links must be SweepReport.CONFIRM_LINKS (%d): "
            .. "the rule is applied there, not here"):format(SweepReport.CONFIRM_LINKS)
    end
    if type(r.pair) ~= "table" or type(r.pair.min_attempts) ~= "number" or r.pair.min_attempts < 1 then
        problems[#problems + 1] = "pair.min_attempts must be a number from 1"
    end
    return #problems == 0, problems
end

function M.policy(key)
    local p = M.POLICIES[key or M.DEFAULT_POLICY]
    if not p then return nil, ("no policy %q"):format(tostring(key)) end
    local ok, problems = M.check_policy(p)
    if not ok then return nil, table.concat(problems, "; ") end
    return p
end

-- --- one run -----------------------------------------------------------------------

-- The run's flags and every location's, sorted: what lab.run_quality reads.
function M.flags_of(run)
    local set = {}
    for _, f in ipairs(run.quality_flags or {}) do set[f] = true end
    for _, s in ipairs(run.sources or {}) do
        for _, f in ipairs(s.quality_flags or {}) do set[f] = true end
    end
    local out = {}
    for f in pairs(set) do out[#out + 1] = f end
    table.sort(out)
    return out
end

-- Returns inclusion, exclusion_reason (nil when counted).
-- Or nil and a problem, for a flag the policy does not classify.
function M.include(run, policy)
    local r = policy.rules
    local flags = {}
    for _, f in ipairs(M.flags_of(run)) do flags[f] = true end

    local classified = {}
    for _, list in ipairs({ r.exclude_run, r.exclude_negative, r.never_exclude }) do
        for _, f in ipairs(list or {}) do classified[f] = true end
    end
    for f in pairs(flags) do
        if not classified[f] then
            return nil, ("run %s carries flag %s, which policy %s does not classify")
                :format(tostring(run.event_key), f, policy.key)
        end
    end

    for _, f in ipairs(r.exclude_run or {}) do
        if flags[f] then return M.INCLUSION.EXCLUDED, f end
    end
    if run.answers == ANSWERS.NEGATIVE then
        for _, f in ipairs(r.exclude_negative or {}) do
            if flags[f] then return M.INCLUSION.EXCLUDED, f end
        end
    end
    return M.INCLUSION.COUNTED, nil
end

-- --- cohorts, and the record ConfirmedEdge reads -------------------------------------

-- A ce.trial.v1 as ConfirmedEdge and ResultCollector read it, rebuilt from the
-- row. conditions carries only the canonical string, which is what
-- TestContext.key reads first; a row with no context has no conditions, which
-- is TestContext.UNRECORDED - the same key the record itself gives.
function M.trial_of(run)
    local edge = (run.subject_kind == M.SUBJECT.EDGE) and run.subject_id or nil
    return {
        schema = Schema.KIND.TRIAL,
        subject_kind = run.subject_kind,
        subject_id = run.subject_id,
        edge_id = edge,
        delays = run.delays,
        attempt = run.attempt,
        verdict = run.verdict,
        recorded_at = run.recorded_at,
        character = run.character,
        control_scheme = run.control_scheme,
        provenance = { game_patch = run.game_patch, calibration_id = run.calibration_id },
        conditions = type(run.context) == "table" and { canonical = run.context.canonical } or nil,
    }
end

function M.cohort_key(run)
    return ResultCollector.cohort_key(M.trial_of(run))
end

-- --- the evidence set ------------------------------------------------------------------

-- The text evidence_set_hash is the SHA-256 of. One line for the policy, then
-- one per run, sorted, so the order the runs arrived in cannot change it:
--   policy=ce-eval-v1;version=1
--   <event_key>\t<counted|excluded>\t<reason or empty>
function M.evidence_set(policy, entries)
    local lines = {}
    for i, e in ipairs(entries or {}) do
        lines[i] = ("%s\t%s\t%s"):format(tostring(e.event_key), tostring(e.inclusion),
                                         e.exclusion_reason or "")
    end
    table.sort(lines)
    return ("policy=%s;version=%s\n"):format(tostring(policy.key), tostring(policy.version))
        .. table.concat(lines, "\n")
end

-- --- the result ----------------------------------------------------------------------

-- c = { successes, failures, reproduced }
function M.result(c)
    local s, f = c.successes or 0, c.failures or 0
    if s + f == 0 then return M.RESULT.PENDING end
    if s > 0 then
        if c.reproduced then return M.RESULT.REPRODUCED end
        if f > 0 then return M.RESULT.MIXED end
        return M.RESULT.OBSERVED_SUCCESS
    end
    return M.RESULT.NO_SUCCESS_OBSERVED
end

-- --- the combo a subject is ----------------------------------------------------------------

-- The steps with their action ids and notations, and the two spellings a list
-- of combos is read by: the moves ("660>655>900", the key the combo page groups
-- by) and the buttons ("AUTO + 强 > 3 + 中 > 2 + SP").
function M.combo_of(route)
    if type(route) ~= "table" or type(route.steps) ~= "table" then return nil end
    local steps, moves, notes = {}, {}, {}
    for i, s in ipairs(route.steps) do
        steps[i] = { step_no = s.step_no or i, kind = s.kind, action_id = s.action_id,
                     input_method = s.input_method, notation = s.notation }
        if s.kind == "move" then
            moves[i] = tostring(s.action_id)
            notes[i] = s.notation or ("%s:%s"):format(tostring(s.action_id), tostring(s.input_method))
        else
            moves[i] = tostring(s.kind)
            notes[i] = tostring(s.kind)
        end
    end
    return { shape_key = route.shape_key, steps = steps,
             moves_key = table.concat(moves, ">"), notation_chain = table.concat(notes, " > ") }
end

-- --- one group ---------------------------------------------------------------------------

local function sorted_keys(t, less)
    local out = {}
    for k in pairs(t) do out[#out + 1] = k end
    table.sort(out, less)
    return out
end

local function count_by_delay(runs)
    local by_delay = {}
    for _, run in ipairs(runs) do
        local key = ResultCollector.delay_key(run.delays) or "?"
        local d = by_delay[key]
        if not d then
            d = { attempts = 0, successes = 0, negatives = 0, unanswered = 0 }
            by_delay[key] = d
        end
        d.attempts = d.attempts + 1
        if run.answers == ANSWERS.POSITIVE then d.successes = d.successes + 1
        elseif run.answers == ANSWERS.NEGATIVE then d.negatives = d.negatives + 1
        else d.unanswered = d.unanswered + 1 end
    end
    return by_delay
end

local function evaluate_group(policy, g)
    local entries, counted = {}, {}
    local successes, failures, unanswered, excluded = 0, 0, 0, 0
    local excluded_by_reason = {}
    local dmin, dmax, dn = nil, nil, 0

    table.sort(g.runs, function(a, b) return a.event_key < b.event_key end)
    for _, run in ipairs(g.runs) do
        local inclusion, reason = M.include(run, policy)
        if not inclusion then return nil, reason end
        entries[#entries + 1] = { event_key = run.event_key, inclusion = inclusion,
                                  exclusion_reason = reason, answer = run.answers }
        if inclusion == M.INCLUSION.EXCLUDED then
            excluded = excluded + 1
            excluded_by_reason[reason] = (excluded_by_reason[reason] or 0) + 1
        else
            counted[#counted + 1] = run
            if run.answers == ANSWERS.POSITIVE then
                successes = successes + 1
                if type(run.measured_damage) == "number" then
                    dn = dn + 1
                    dmin = math.min(dmin or run.measured_damage, run.measured_damage)
                    dmax = math.max(dmax or run.measured_damage, run.measured_damage)
                end
            elseif run.answers == ANSWERS.NEGATIVE then
                failures = failures + 1
            else
                unanswered = unanswered + 1
            end
        end
    end

    local summary = { excluded_by_reason = excluded_by_reason }
    local reproduced = false

    if g.subject_kind == M.SUBJECT.EDGE then
        summary.rule = "confirmed_edge"
        if #counted > 0 then
            local trials = {}
            for i, run in ipairs(counted) do trials[i] = M.trial_of(run) end
            local edge, why = ConfirmedEdge.fold(trials, { min_attempts = policy.rules.pair.min_attempts })
            if not edge then
                return nil, ("%s %s: ConfirmedEdge refused the counted runs: %s")
                    :format(g.subject_kind, g.subject_id, tostring(why))
            end
            -- The fold counted what it was given; if it disagrees with the
            -- tally above, one of the two is reading the verdicts differently.
            if edge.successes ~= successes or edge.negatives ~= failures or edge.unanswered ~= unanswered then
                return nil, ("%s: ConfirmedEdge counted %d/%d/%d, the policy %d/%d/%d")
                    :format(g.subject_id, edge.successes, edge.negatives, edge.unanswered,
                            successes, failures, unanswered)
            end
            reproduced = (edge.stable == true and edge.successes > 0)
            summary.by_delay = edge.by_delay
            summary.window = edge.window
            summary.stable = edge.stable
            summary.confirmed_edge_status = edge.status
            summary.reason = edge.reason
        else
            summary.by_delay = {}
            summary.stable = false
        end
    else
        summary.rule = "combo_links"
        summary.by_delay = count_by_delay(counted)
        local status = SweepReport.combo_status(successes)
        summary.combo_status = status
        reproduced = (status == SweepReport.COMBO.CONFIRMED)
    end

    local linked = {}
    for key, d in pairs(summary.by_delay) do
        if d.successes > 0 then linked[#linked + 1] = key end
    end
    table.sort(linked, SweepReport.gap_less)
    summary.linked_gaps = linked
    if dn > 0 then summary.damage = { samples = dn, min = dmin, max = dmax } end

    return {
        kind = "evaluation",
        policy_key = policy.key,
        policy_version = policy.version,
        subject_kind = g.subject_kind,
        subject_id = g.subject_id,
        test_kind = g.test_kind,
        character = g.character,
        control_scheme = g.control_scheme,
        cohort_key = g.cohort_key,
        route = g.route,
        combo = M.combo_of(g.route),
        result = M.result({ successes = successes, failures = failures, reproduced = reproduced }),
        successful_runs = successes,
        conclusive_failures = failures,
        unanswered_runs = unanswered,
        excluded_runs = excluded,
        measured_summary = summary,
        runs = entries,
        evidence_set = M.evidence_set(policy, entries),
    }
end

-- --- the whole set ----------------------------------------------------------------------

-- runs : distinct lab runs (labrows rows + event_key + sources), any order
-- opts.policy : a policy key (default M.DEFAULT_POLICY)
--
-- Returns evaluations (sorted by subject kind, subject, cohort), problems.
-- A run that cannot be placed is a problem, never silently dropped, and a
-- group with a problem produces no evaluation - a partial evidence set would
-- hash to a real-looking id.
function M.evaluate(runs, opts)
    opts = opts or {}
    local policy, perr = M.policy(opts.policy)
    if not policy then return nil, { perr } end

    local problems = {}
    local groups, seen = {}, {}
    for i, run in ipairs(runs or {}) do
        local why
        if type(run) ~= "table" then why = "not a run"
        elseif type(run.event_key) ~= "string" or run.event_key == "" then why = "no event_key"
        elseif seen[run.event_key] then why = "event_key " .. run.event_key .. " given twice: the caller merges identical observations"
        elseif run.subject_kind ~= M.SUBJECT.EDGE and run.subject_kind ~= M.SUBJECT.ROUTE then
            why = ("subject_kind %s is neither edge nor route"):format(tostring(run.subject_kind))
        elseif type(run.subject_id) ~= "string" then why = "no subject_id"
        elseif ResultCollector.classify(run.verdict) ~= run.answers then
            why = ("answers %s does not follow verdict %s"):format(tostring(run.answers), tostring(run.verdict))
        end
        if why then
            problems[#problems + 1] = ("run %d (%s): %s"):format(i, tostring(type(run) == "table" and run.event_key), why)
        else
            seen[run.event_key] = true
            local cohort = M.cohort_key(run)
            local key = table.concat({ run.subject_kind, run.subject_id, cohort }, "\n")
            local g = groups[key]
            if not g then
                g = { subject_kind = run.subject_kind, subject_id = run.subject_id,
                      test_kind = run.test_kind, character = run.character,
                      control_scheme = run.control_scheme, cohort_key = cohort,
                      route = run.route, runs = {} }
                groups[key] = g
            elseif g.route == nil then
                g.route = run.route
            end
            g.runs[#g.runs + 1] = run
        end
    end

    local out = {}
    for _, key in ipairs(sorted_keys(groups)) do
        local ev, why = evaluate_group(policy, groups[key])
        if ev then out[#out + 1] = ev else problems[#problems + 1] = why end
    end
    return out, problems, policy
end

-- Counts for a report line: evaluations by result and subject kind, exclusions by reason.
function M.tally(evaluations)
    local t = { by_result = {}, by_kind_result = {}, excluded_by_reason = {}, runs = 0 }
    for _, ev in ipairs(evaluations or {}) do
        t.by_result[ev.result] = (t.by_result[ev.result] or 0) + 1
        local k = ev.subject_kind .. ":" .. ev.result
        t.by_kind_result[k] = (t.by_kind_result[k] or 0) + 1
        for reason, n in pairs(ev.measured_summary.excluded_by_reason) do
            t.excluded_by_reason[reason] = (t.excluded_by_reason[reason] or 0) + n
        end
        t.runs = t.runs + #ev.runs
    end
    return t
end

return M
