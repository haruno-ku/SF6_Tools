-- =========================================================
-- tools/lua/verifiedcombo.lua - lab evaluations in, ce.verified_combo.v1 out,
-- or a reason why not. Pure: tables in, tables out. No files, no json, no
-- database, no game.
-- =========================================================
--
-- THE GAP THIS FILLS
--
-- The chain was: trials -> lab.runs -> lab.evaluations (policy ce-eval-v1) ->
-- ce.verified_combo.v1 -> KnowledgeDb.export -> a page. The last two links had
-- no caller and the third had no producer (#51). An evaluation says "under this
-- policy, in this cohort, this subject reproduced"; a verified combo says "this
-- combo does this much damage, measured here, on this patch, under this
-- calibration". The second is a stronger claim than the first, and the whole
-- job of this module is the gap between them.
--
-- IT PRODUCES NOTHING IT WAS NOT GIVEN
--
-- Five rules, and every one of them is a refusal to invent:
--
--   1. Only `reproduced`. The policy's other four results are honest answers -
--      pending, mixed, observed_success, no_success_observed - and none of them
--      is "this combo works". observed_success in particular is one link, or
--      links that never repeated at one delay, and publishing it would be
--      publishing a coin that came up heads once.
--
--   2. measured.damage or nothing. The figure comes from the counted links'
--      own evidence.damage and from nowhere else. There is no default, no zero
--      and no fallback to Scoring.predicted_damage - which is an unscaled
--      frame-table sum, a different quantity from a training-mode measurement,
--      and also CC-BY-SA where this is not (docs/NOTICE.md). A reproduced
--      subject with no damage reading is not dropped: it goes on the refused
--      list with the reason, because that list IS the work list for the next
--      session on the game.
--
--   3. The counted links have to agree. Two links in one cohort that read
--      different damage are a measurement this module cannot resolve into one
--      number, and the mean of them is a number no trial produced. Refused,
--      with both readings named.
--
--   4. measured carries only what the runtime actually records: damage, the hit
--      count, and the Drive / Super gauges at both ends of the observation
--      window when the runs have them. Not drive_spent, not sa_gain, not
--      advantage frames, not the knockdown type - nothing measures those today,
--      and the record SAYS SO in measured.unmeasured rather than leaving the
--      keys absent for a reader to interpret as zero.
--
--   5. Every record goes through Schema.validate(KIND.COMBO, rec) before it is
--      returned. A record this module built that the schema refuses is a defect
--      here, not a fact about the game, and it comes back on the refused list
--      flagged `bug = true` so a caller can fail loudly instead of publishing
--      around it.
--
-- WHAT A RECORD'S route_id MEANS
--
-- A route subject has a real ce.route.v1 behind it and route_id is its id. A
-- PAIR subject does not: "617:manual->1206:manual" is an edge, and the two-step
-- route it implies was never authored as a route file. Its route_id is the edge
-- key, and `route_source` says which of the two it was, so nobody later reads
-- an edge key as a missing route document. The steps themselves are the same
-- shape either way, because labeval.combo_of builds both.
--
-- THE COHORT IS PART OF THE CLAIM
--
-- One evaluation is one subject in ONE cohort (patch, calibration, character,
-- scheme, conditions), so one record is too, and the cohort tag is in the id -
-- the same reasoning ConfirmedEdge gives for putting it in its own. Two cohorts
-- that reproduced the same pair are two records, and KnowledgeDb's gate will
-- turn away whichever one was not measured on the patch and calibration being
-- exported for. That is the correct outcome: the other one is a measurement of
-- a different build.
--
-- LICENCE
--
-- Everything a record carries was measured on Street Fighter 6. No value in it
-- is computed from the frame data, so it inherits no CC-BY-SA obligation - the
-- same split confirm.lua's licence_note states, for the same reason.

local Schema      = require("func/ComboExplorer/core/Schema")
local TestContext = require("func/ComboExplorer/core/TestContext")
local LabEval     = dofile("tools/lua/labeval.lua")

local M = { name = "tools.verifiedcombo" }

-- Why a reproduced subject did not become a publishable record. Named so a
-- report can group by them and a test can pin them; the strings are what a
-- reader sees.
M.REASON = {
    NOT_REPRODUCED      = "not_reproduced",
    NO_STEPS            = "no_steps",
    INVALID_STEP        = "invalid_step",
    NO_COHORT           = "cohort_not_identified",
    DAMAGE_NOT_MEASURED = "damage_not_measured",
    DAMAGE_DISAGREES    = "counted_links_disagree_on_damage",
    SCHEMA_REFUSED      = "schema_refused_the_record",
}

-- What the record says it did not measure, and why. Every one of these is a
-- field the target (sf6-knowledge-db) has a slot for and nothing in this
-- project fills; several are named in Schema.RUNTIME_UNKNOWNS, and those say
-- so. Written into every record rather than computed per caller: a gap that is
-- only in a report is a gap the data does not admit to.
local U = Schema.RUNTIME_UNKNOWNS

M.UNMEASURED = {
    { field = "hits",
      why = "the trial's damage block carried no combo-counter reading" },
    { field = "drive_spent",
      why = "the runtime reads the Drive bar at both ends of the observation "
         .. "window and does not decide which part of the change is a spend" },
    { field = "drive_gain",
      why = "the same reading as drive_spent, and the same undecided question" },
    { field = "sa_gain",
      why = "the Super bar is read at both ends; how much of the change the "
         .. "combo caused is not decided" },
    { field = "advantage_frames",
      why = "nothing measures the frame advantage after a combo ends",
      unknown = U.KNOCKDOWN },
    { field = "knockdown_type",
      why = "no knockdown property is read on this build",
      unknown = U.KNOCKDOWN },
    { field = "back_rise_allowed",
      why = "the wake-up options after the combo were never observed",
      unknown = U.KNOCKDOWN },
    { field = "ends_in_corner",
      why = "the position after the combo was never read",
      unknown = U.CORNER },
    { field = "side_switch",
      why = "which side the attacker finished on was never read",
      unknown = U.SIDE_SWITCH },
    { field = "distance_class",
      why = "the distance between the two after the combo was never read",
      unknown = U.PUSHBACK_RANGE },
    { field = "position",
      why = "the trial's conditions record where the stage reset to, which is "
         .. "not the same statement as \"this combo needs the corner\"" },
    { field = "counter",
      why = "the counter state was unknown in every committed trial's conditions" },
    { field = "difficulty",
      why = "difficulty is a human judgement in the target and is never derived "
         .. "from the execution cost, which is a prediction about how much there "
         .. "is to do" },
}

-- --- small helpers -----------------------------------------------------------

-- The same short tag ResultCollector.cohort_tag produces, taken over a cohort
-- key that has already been computed. Only a label: the KEY is the identity.
function M.cohort_tag(cohort_key)
    local h = TestContext.hash(cohort_key or "") or "fnv1a64:0"
    return h:sub(9, 16)
end

-- "verified <subject> @ <cohort tag>", the spelling ConfirmedEdge uses for the
-- same reason: two cohorts that answered about one subject are two records and
-- must not collide.
function M.id_for(ev)
    return ("verified %s @ %s"):format(tostring(ev.subject_id),
                                       M.cohort_tag(ev.cohort_key))
end

local function copy_list(list)
    local out = {}
    for i, v in ipairs(list or {}) do out[i] = v end
    return out
end

local function refusal(ev, reason, detail, extra)
    local r = {
        subject_kind = ev and ev.subject_kind,
        subject_id = ev and ev.subject_id,
        cohort_key = ev and ev.cohort_key,
        result = ev and ev.result,
        notation_chain = ev and ev.combo and ev.combo.notation_chain,
        reason = reason,
        detail = detail,
    }
    for k, v in pairs(extra or {}) do r[k] = v end
    return r
end

-- One reading, when the counted links agree on it. Returns value, problem.
-- A span with samples = 0 cannot happen (span only counts readings), so the
-- only two answers are "nobody read it" and "they disagree".
local function one_reading(sp)
    if type(sp) ~= "table" or (sp.samples or 0) == 0 then return nil, nil end
    if sp.min ~= sp.max then return nil, sp end
    return sp.min, nil
end

-- --- the steps ---------------------------------------------------------------

-- The route KnowledgeDb reads, built from the evaluation's own combo block.
-- Nothing is looked up: the action id, the input method and the notation are
-- what the trial pressed, which is the only reading of the route that is a
-- measurement rather than a plan.
--
-- opts.classic_of(action_id) is optional and used for display only - the
-- catalog's classic command travels with a step so that a move still missing a
-- moves.yaml slug can be named to whoever has to add it.
local function steps_of(ev, opts)
    local combo = ev.combo
    if type(combo) ~= "table" or type(combo.steps) ~= "table" or #combo.steps == 0 then
        return nil, refusal(ev, M.REASON.NO_STEPS,
            "the evaluation carries no combo steps, so there is no route to publish")
    end
    local out = {}
    for i, s in ipairs(combo.steps) do
        if s.kind ~= "move" then
            return nil, refusal(ev, M.REASON.INVALID_STEP,
                ("step %d is a %s, and only moves can be named to the target"
                 ):format(i, tostring(s.kind)))
        end
        if s.action_id == nil or s.input_method == nil then
            return nil, refusal(ev, M.REASON.INVALID_STEP,
                ("step %d names no action id or no input method"):format(i))
        end
        out[i] = {
            step_no = s.step_no or i,
            action_id = s.action_id,
            input_method = s.input_method,
            notation = s.notation,
            classic = opts.classic_of and opts.classic_of(s.action_id) or nil,
        }
    end
    return out, nil
end

-- --- one evaluation ----------------------------------------------------------

-- ev   : one evaluation from tools/lua/labeval.lua
-- opts : character (the catalog name, for the record; the evaluation's own is
--        used when it has one), classic_of, explorer_version
--
-- Returns record, refusal. Exactly one of them is non-nil.
function M.from_evaluation(ev, opts)
    opts = opts or {}
    if type(ev) ~= "table" then
        return nil, refusal(nil, M.REASON.NOT_REPRODUCED, "not an evaluation")
    end

    if ev.result ~= LabEval.RESULT.REPRODUCED then
        return nil, refusal(ev, M.REASON.NOT_REPRODUCED,
            ("the policy calls this %s, which is not a claim that the combo works"
             ):format(tostring(ev.result)))
    end

    if ev.game_patch == nil or ev.calibration_id == nil then
        return nil, refusal(ev, M.REASON.NO_COHORT,
            "a verified record has to name the patch and calibration it was "
            .. "measured on, and the evaluation names neither")
    end

    local steps, why = steps_of(ev, opts)
    if not steps then return nil, why end

    local summary = ev.measured_summary or {}

    -- Rule 2, and the one that refuses everything today.
    local damage, spread = one_reading(summary.damage)
    if spread then
        return nil, refusal(ev, M.REASON.DAMAGE_DISAGREES,
            ("%d counted links read between %s and %s damage; the mean of them is "
             .. "a figure no trial produced"):format(spread.samples,
                tostring(spread.min), tostring(spread.max)),
            { damage = spread })
    end
    if damage == nil then
        return nil, refusal(ev, M.REASON.DAMAGE_NOT_MEASURED,
            ("%d counted link(s), none of which recorded a damage figure. Running "
             .. "this route with RouteRun records one (evidence.damage)."
             ):format(ev.successful_runs or 0),
            { successful_runs = ev.successful_runs, linked_gaps = copy_list(summary.linked_gaps) })
    end

    local hits = one_reading(summary.hits)

    -- What the record admits it does not know. hits is only listed when it is
    -- genuinely absent; everything else in M.UNMEASURED is unmeasured on every
    -- record this project can produce today.
    local unmeasured = {}
    for _, u in ipairs(M.UNMEASURED) do
        if not (u.field == "hits" and hits ~= nil) then
            unmeasured[#unmeasured + 1] = { field = u.field, why = u.why, unknown = u.unknown }
        end
    end

    local measured = {
        damage = damage,
        hits = hits,
        -- Carried as read, both ends, both bars. Whichever of spend and gain a
        -- change is, it is not decided here.
        gauges = summary.gauges,
        unmeasured = unmeasured,
    }

    local route_id = ev.subject_id
    local rec = {
        schema = Schema.KIND.COMBO,
        id = M.id_for(ev),
        route_id = route_id,
        route_source = (ev.subject_kind == LabEval.SUBJECT.ROUTE)
            and "a ce.route.v1 that was run end to end"
            or "the pair itself: an edge subject implies a two-step route that "
               .. "was never authored as a route file",
        status = Schema.STATUS.VERIFIED,
        runtime_verified = true,
        -- The policy said reproduced; `stable` is the word the schema and
        -- KnowledgeDb's gate read, and it means the same thing here.
        stable = true,
        character = ev.character or opts.character,
        control_scheme = ev.control_scheme,
        subject_kind = ev.subject_kind,
        cohort_key = ev.cohort_key,
        measured = measured,
        -- Everything the claim rests on, in the record, because the person
        -- reading it is on another machine and cannot re-run the policy.
        evidence = {
            policy_key = ev.policy_key,
            policy_version = ev.policy_version,
            rule = summary.rule,
            successful_runs = ev.successful_runs,
            conclusive_failures = ev.conclusive_failures,
            unanswered_runs = ev.unanswered_runs,
            excluded_runs = ev.excluded_runs,
            linked_gaps = copy_list(summary.linked_gaps),
            window = summary.window,
            excluded_by_reason = summary.excluded_by_reason,
            -- How many links each figure in `measured` rests on, and that they
            -- agreed (min = max, or the record would not exist). It belongs
            -- here rather than in `measured`, which holds readings only.
            damage_span = summary.damage,
            hits_span = summary.hits,
            evidence_set = ev.evidence_set,
        },
        provenance = {
            game_patch = ev.game_patch,
            calibration_id = ev.calibration_id,
            cohort_key = ev.cohort_key,
            policy = ev.policy_key,
            explorer_version = opts.explorer_version,
            source = "tools/lua/verifiedcombo.lua over lab evaluations",
            licence_note = "Measured on Street Fighter 6. No value in this record "
                .. "is derived from the frame data, so it carries no CC-BY-SA "
                .. "obligation; see docs/NOTICE.md.",
        },
        route = {
            id = route_id,
            character = ev.character or opts.character,
            control_scheme = ev.control_scheme,
            steps = steps,
            moves_key = ev.combo and ev.combo.moves_key,
            notation_chain = ev.combo and ev.combo.notation_chain,
        },
    }

    -- Rule 5. Last, and on the finished record, so what is checked is exactly
    -- what would be returned.
    local ok, problems = Schema.validate(Schema.KIND.COMBO, rec)
    if not ok then
        return nil, refusal(ev, M.REASON.SCHEMA_REFUSED,
            "this module built a record ce.verified_combo.v1 refuses, which is a "
            .. "defect in tools/lua/verifiedcombo.lua and not a fact about the game",
            { problems = problems, bug = true })
    end

    return rec, nil
end

-- --- the whole set -----------------------------------------------------------

-- evaluations : from tools/lua/labknown.lua or tools/lua/labeval.lua, any order
-- opts        : see M.from_evaluation
--
-- Returns records, refused, counts. Every evaluation given produces exactly one
-- of the two, so nothing is silently dropped - which is the point: on today's
-- logs the refused list is the entire output, and it is the work list.
function M.build(evaluations, opts)
    local records, refused = {}, {}
    local counts = { evaluations = 0, records = 0, refused = 0,
                     by_reason = {}, by_result = {}, bugs = 0 }

    for _, ev in ipairs(evaluations or {}) do
        counts.evaluations = counts.evaluations + 1
        local result = (type(ev) == "table") and tostring(ev.result) or "(not an evaluation)"
        counts.by_result[result] = (counts.by_result[result] or 0) + 1

        local rec, why = M.from_evaluation(ev, opts)
        if rec then
            records[#records + 1] = rec
        else
            refused[#refused + 1] = why
            counts.by_reason[why.reason] = (counts.by_reason[why.reason] or 0) + 1
            if why.bug then counts.bugs = counts.bugs + 1 end
        end
    end

    counts.records = #records
    counts.refused = #refused
    return records, refused, counts
end

-- The refusals that are about a subject the policy already believes in - the
-- ones a session on the game can clear. A `not_reproduced` refusal is not one
-- of them: no amount of measuring makes a pending subject reproduced except
-- more trials, which is a different piece of work.
function M.blocked_by_measurement(refused)
    local out = {}
    for _, r in ipairs(refused or {}) do
        if r.reason == M.REASON.DAMAGE_NOT_MEASURED or r.reason == M.REASON.DAMAGE_DISAGREES then
            out[#out + 1] = r
        end
    end
    return out
end

return M
