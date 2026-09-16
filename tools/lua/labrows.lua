-- =========================================================
-- tools/lua/labrows.lua - one ce.trial.v1 line in, one lab.runs row out, with
-- the fields the database indexes and the quality flags that let an evaluation
-- leave a broken experiment out. Pure: no files, no json, no catalog loading.
-- Whatever needs the catalog or another file is handed in by the caller
-- (tools/lua/labrows-cli.lua), so every rule below is testable on a table.
-- =========================================================
--
-- WHY THE ROWS ARE BUILT IN LUA AND THE SQL IN NODE
--
-- The rules that say what a trial was ABOUT already exist here, in the modules
-- that wrote the trials: ResultCollector reads a legacy route row through its
-- fake edge id, TestContext says what the conditions' identity is,
-- CandidateGenerator names a pair's mechanism, Timing counts a motion's ticks,
-- SequenceCompiler decides what cannot be pressed. A second spelling of any of
-- them in JavaScript would be a second place for the answer to drift (#38 asks
-- for exactly one). So this module emits plain rows, and Lua never builds a SQL
-- string - quoting is the Node side's single job.
--
-- WHAT A FLAG IS, AND WHAT IT IS NOT
--
-- A flag is data about a row, never a deletion. Every trial on disk is
-- imported (#38: corrections are new rows, nothing is tidied away), and an
-- evaluation decides which flags it excludes. A row can carry several.
--
-- Each flag is a rule stated over the record and the file it came from, not an
-- opinion about the result. A flagged `link` is still a link; the flag says the
-- experiment behind it was not the one its fields suggest.
--
--   legacy_route_subject
--     The row is a route run written before #14, stored as an EDGE whose id is
--     the route's with its gaps appended ("zangief-assist-ground-truth@40/2").
--     ResultCollector.recorded_subject sees through it; the row is imported as
--     the route it was about, and the flag says the subject was reconstructed.
--
--   evidence_missing
--     An unanswered trial with no evidence block. Before b5f67bc
--     (2026-09-14T02:18:14Z) ResultCollector cleared evidence on entering
--     runtime_pending and never put it back, so every wrong_move lost
--     actions_seen, a_hit and the stage - what would say WHY. The reason string
--     survived. Not repairable: the observation ended with the trial.
--
--   link_timing_on_cancel_pair
--     A pair whose mechanism (CandidateGenerator.mechanism, over the edge the
--     generator produces TODAY) is `cancel`, on a row with no `timing` block
--     from a file that swept a predicted gap. Before be1c0be every pair was
--     pressed at Timing.window's LINK gap, after A had recovered, where no
--     cancel exists - so a negative there is not evidence the cancel fails.
--     Not set on a fixed-gap file (delay4): gap 4 lands inside A's hitstop,
--     which is cancel timing, and that file has its own flag.
--
--   motion_button_late
--     A pair whose B has a multi-direction motion (Timing.motion_ticks > 0), on
--     a row with no `timing` block. SequenceCompiler plays one tick per
--     direction and holds only the last with the button, so B's BUTTON came
--     motion_ticks after the recorded delay. be1c0be takes the motion off the
--     gap; rows before it pressed the button that much late (720 is ten ticks).
--
--   fixed_delay_4
--     The row is from zangief-modern-delay4.jsonl: every pair at gap 4, which
--     is inside A's animation - a cancel window, not a link window (#46,
--     1e2eb5b). Its negatives were never measurements of whether a pair links.
--
--   superseded_rerun
--     The file was re-run with a defect fixed, and the re-run holds a row with
--     the same ResultCollector.key (subject, delays, attempt) in the same cohort
--     (ResultCollector.cohort_key). Decided per ROW, not per file name:
--       *-framedata-singleid  -> framedata   (0370f6c: a step expected one id
--                                            where the catalog gives a group)
--       *-ground-truth-pre-group -> ground-truth (9a1cea9 / 8c7e9f2: same defect
--                                            on the route runner)
--     gap2to28 is NOT superseded: nothing re-ran those 144 keys. They were run
--     before the group fix, but their reason is "no other action followed A",
--     which the fix cannot change. The same 144 lines sit inside the pre-group
--     file, and because this rule is per row they are not flagged there either.
--     The superseding row carries `supersedes` pointing at the one it replaces.
--
--   unplayable_input
--     SequenceCompiler.unplayable would set the route aside today (#49): a
--     repeated direction (22 plays as one held 2), a follow-up opening a route,
--     a follow-up after a move nothing says it follows, or a Drive Rush step.
--     A sweep pair gets context_known from the generator's edge; a route an
--     operator named vouches for its own order.
--
-- UNKNOWN STAYS NIL
--
-- A field that was not recorded is absent from the row (JSON null in the
-- database), never 0 or false: no damage reading is not zero damage, no
-- conditions is not "uncontrolled", a pair the generator does not produce
-- today has no mechanism rather than "link". The derived block says which of
-- those it was, so a reader never has to infer it from a missing key.

local ResultCollector  = require("func/ComboExplorer/core/ResultCollector")
local TestContext      = require("func/ComboExplorer/core/TestContext")
local SequenceCompiler = require("func/ComboExplorer/core/SequenceCompiler")
local CG               = require("func/ComboExplorer/core/CandidateGenerator")
local Timing           = require("func/ComboExplorer/core/Timing")

local M = { name = "tools.labrows" }

-- Bumped when a rule below changes what a row or a flag says. Recorded on every
-- row's derived block and on the import batch, so a flag set by an older rule
-- can be told apart from one set by this one.
M.VERSION = "ce.labrows.v1"

M.FLAG = {
    LEGACY_ROUTE_SUBJECT       = "legacy_route_subject",
    EVIDENCE_MISSING           = "evidence_missing",
    LINK_TIMING_ON_CANCEL_PAIR = "link_timing_on_cancel_pair",
    MOTION_BUTTON_LATE         = "motion_button_late",
    FIXED_DELAY_4              = "fixed_delay_4",
    SUPERSEDED_RERUN           = "superseded_rerun",
    UNPLAYABLE_INPUT           = "unplayable_input",
}

M.TEST_KIND = { PAIR_LINK = "pair_link", FULL_COMBO = "full_combo" }

-- b5f67bc's author date. Only used to word the reason: the flag is set on any
-- unanswered row without evidence, because a row after the fix with none would
-- be the same missing fact from a different bug.
M.EVIDENCE_KEPT_FROM = "2026-09-14T02:18:14Z"

-- What is known about each committed trial file, by base name. A file not
-- listed here has no file-level rule; every per-row rule still applies.
M.FILES = {
    ["zangief-modern-delay4.jsonl"] = {
        fixed_gap = 4,
        flags = { M.FLAG.FIXED_DELAY_4 },
        why = "every pair at gap 4, inside A's animation: a cancel window, not a link window (#46, 1e2eb5b)",
    },
    ["zangief-modern-framedata-singleid.jsonl"] = {
        superseded_by = "zangief-modern-framedata.jsonl",
        why = "a step expected one action id where the catalog names a group; re-run after Catalog.group_ids (0370f6c)",
    },
    ["zangief-assist-ground-truth-pre-group.jsonl"] = {
        superseded_by = "zangief-assist-ground-truth.jsonl",
        why = "read before a route step expected its whole notation group; re-run after 9a1cea9 (8c7e9f2)",
    },
}

-- --- small pieces --------------------------------------------------------------

local function basename(path)
    if type(path) ~= "string" then return nil end
    return path:match("([^/\\]+)$") or path
end
M.basename = basename

local function is_int(v)
    return math.type(v) == "integer" or (type(v) == "number" and v == math.floor(v)
        and v > -2^53 and v < 2^53)
end

local function int_or_nil(v)
    if type(v) ~= "number" or not is_int(v) then return nil end
    return math.tointeger(v)
end

-- A gauge reading is a bar position, not a count, so it is not put through
-- int_or_nil: rounding it here would be this module deciding what the units are.
local function num_or_nil(v)
    if type(v) ~= "number" or v ~= v then return nil end
    return v
end

local function sorted_keys(set)
    local out = {}
    for k in pairs(set) do out[#out + 1] = k end
    table.sort(out)
    return out
end

-- "601:manual->678:manual" -> { {action_id=601,input_method="manual"}, {...} }
-- nil for anything else, including a legacy route id.
function M.pair_steps(edge_id)
    if type(edge_id) ~= "string" then return nil end
    local a, am, b, bm = edge_id:match("^(%d+):([%w_]+)%->(%d+):([%w_]+)$")
    if not a then return nil end
    return {
        { step_no = 1, kind = "move", action_id = tonumber(a), input_method = am },
        { step_no = 2, kind = "move", action_id = tonumber(b), input_method = bm },
    }
end

-- The route's identity inside one character and scheme: the moves in order, by
-- action id and input method. Notation is display and stays out of it - the
-- same id under a renamed notation is the same route. A Drive Rush step is
-- spelled by its kind, because it has no action id anyone agrees on.
function M.shape_key(steps)
    if type(steps) ~= "table" or #steps == 0 then return nil, "a route has at least one step" end
    local parts = {}
    for i, s in ipairs(steps) do
        if s.kind == SequenceCompiler.DRIVE_RUSH_STEP then
            parts[i] = SequenceCompiler.DRIVE_RUSH_STEP
        else
            local id = int_or_nil(s.action_id)
            if not id or type(s.input_method) ~= "string" or s.input_method == "" then
                return nil, ("step %d has no action id and input method"):format(i)
            end
            parts[i] = ("%d:%s"):format(id, s.input_method)
        end
    end
    return table.concat(parts, ">")
end

-- A ce.route.v1 definition's steps, numbered and with the kind spelled out.
function M.definition_steps(def)
    if type(def) ~= "table" or type(def.steps) ~= "table" then return nil end
    local out = {}
    for i, s in ipairs(def.steps) do
        if s.kind == SequenceCompiler.DRIVE_RUSH_STEP then
            out[i] = { step_no = i, kind = SequenceCompiler.DRIVE_RUSH_STEP }
        else
            out[i] = { step_no = i, kind = "move", action_id = int_or_nil(s.action_id),
                       input_method = s.input_method, notation = s.notation or s.classic }
        end
    end
    return out
end

-- --- conditions -----------------------------------------------------------------

-- The test_contexts row for a record's conditions. nil, and no problem, when
-- the record has none: "nobody recorded the conditions" is a fact about the
-- row, not a context. A record whose canonical string disagrees with its own
-- fields is refused - the string is the identity, and one that does not
-- describe the record cannot be believed about it.
function M.context_of(conditions)
    if conditions == nil then return nil end
    if type(conditions) ~= "table" then return nil, "conditions is not an object" end
    local canon, why = TestContext.canonical(conditions)
    if not canon then return nil, "conditions: " .. tostring(why) end
    if conditions.canonical ~= nil and conditions.canonical ~= canon then
        return nil, ("conditions.canonical %q does not describe its own fields (%q)")
            :format(tostring(conditions.canonical), canon)
    end
    local opp = type(conditions.opponent) == "table" and conditions.opponent or nil
    return {
        schema = conditions.schema,
        canonical = canon,
        -- Recomputed rather than copied: an index built from a different
        -- string than the one stored would be an index to the wrong row.
        context_hash = TestContext.hash(canon),
        counter_state = conditions.counter_state,
        screen_position = conditions.screen_position,
        positions_controlled = conditions.positions.controlled,
        resources_pinned = conditions.resources.pinned,
        opponent_character = opp and type(opp.character) == "string" and opp.character ~= ""
            and opp.character or nil,
    }
end

-- --- the index a superseding file is looked up in ------------------------------------

-- The composite a re-run has to share with a row to replace it: the resume key
-- and the cohort. The cohort, because a row from a different calibration with
-- the same key is a different experiment, not a re-run of this one.
function M.rerun_key(rec)
    local key = ResultCollector.key(rec)
    if not key then return nil end
    return key .. " | " .. ResultCollector.cohort_key(rec)
end

-- records : list of { line_no = n, record = rec }
-- Returns composite -> line_no, with `false` for a composite that appears more
-- than once: a supersedes pointer that had to pick one of two rows would be a
-- guess, so a repeated key is recorded as ambiguous and points at nothing.
function M.index_reruns(records)
    local ix = {}
    for _, r in ipairs(records or {}) do
        local k = M.rerun_key(r.record)
        if k then
            if ix[k] == nil then ix[k] = r.line_no else ix[k] = false end
        end
    end
    return ix
end

-- --- the row ---------------------------------------------------------------------

-- rec : a decoded ce.trial.v1
-- fc  : the file context
--   source_file  : repo-relative path; its base name selects M.FILES
--   line_no      : 1-based
--   lookup.pair(character, scheme, key)
--       -> { mechanism, context_known, a_notation, b_notation,
--            status = "candidate"|"excluded", exclusion } or nil
--   lookup.notation(character, scheme, action_id, input_method) -> string or nil
--   lookup.route(route_id) -> a ce.route.v1 definition or nil
--   successor    : M.index_reruns over the file this one is superseded by
--   predecessor  : { source_file = path, index = M.index_reruns(...) } for the
--                  file this one supersedes
--
-- Returns row, or nil and a list of problems.
function M.row(rec, fc)
    fc = fc or {}
    local problems = {}
    local function problem(field, msg) problems[#problems + 1] = { field = field, problem = msg } end

    if type(rec) ~= "table" then return nil, { { field = "(root)", problem = "not a record" } } end
    if rec.schema ~= "ce.trial.v1" then
        problem("schema", ("schema %q is not ce.trial.v1"):format(tostring(rec.schema)))
    end

    local recorded, serr = ResultCollector.subject(rec)
    if not recorded then problem("subject", serr) end
    local subject = recorded and ResultCollector.recorded_subject(rec) or nil

    local delays, derr = ResultCollector.delay_list(rec.delays or rec.delay)
    if not delays then problem("delays", derr) end

    local attempt = int_or_nil(rec.attempt)
    if not attempt or attempt < 1 then problem("attempt", "attempt is not a whole number from 1") end

    local answers, verr = ResultCollector.classify(rec.verdict)
    if not answers then problem("verdict", verr) end
    if answers and rec.answers ~= nil and rec.answers ~= answers then
        problem("answers", ("the record says %s, and verdict %s means %s")
            :format(tostring(rec.answers), tostring(rec.verdict), answers))
    end

    local context, cerr = M.context_of(rec.conditions)
    if cerr then problem("conditions", cerr) end

    if #problems > 0 then return nil, problems end

    local lookup = fc.lookup or {}
    local character, scheme = rec.character, rec.control_scheme
    local provenance = type(rec.provenance) == "table" and rec.provenance or {}
    local file = basename(fc.source_file)
    local rule = M.FILES[file] or {}

    local flags, reasons = {}, {}
    local function flag(name, why)
        flags[name] = true
        reasons[name] = reasons[name] and (reasons[name] .. "; " .. why) or why
    end

    local derived = { labrows_version = M.VERSION }

    -- The subject, and the route it is.
    local steps, context_known
    local is_pair = (subject.kind == "edge")
    if subject.legacy then
        flag(M.FLAG.LEGACY_ROUTE_SUBJECT,
             ("recorded as edge %q before a route could be a subject (#14)"):format(recorded.id))
        derived.legacy_gaps = subject.gaps
    end
    if is_pair then
        steps = M.pair_steps(subject.id)
        local info = lookup.pair and lookup.pair(character, scheme, subject.id) or nil
        if steps then
            steps[1].notation = (info and info.a_notation)
                or (lookup.notation and lookup.notation(character, scheme, steps[1].action_id, steps[1].input_method))
            steps[2].notation = (info and info.b_notation)
                or (lookup.notation and lookup.notation(character, scheme, steps[2].action_id, steps[2].input_method))
        end
        if info then
            derived.candidate = info.status
            derived.exclusion = info.exclusion
            derived.mechanism = info.mechanism
            context_known = (info.context_known == true)
        else
            -- Not the same as excluded: nothing was loaded that could say.
            derived.candidate = "unknown"
        end
    else
        local def = lookup.route and lookup.route(subject.id) or nil
        steps = M.definition_steps(def)
        derived.route_definition = def and def.id or nil
        -- Whoever wrote a route named its order; that is the vouch #49 needs.
        context_known = true
    end

    local route
    if steps then
        local shape = M.shape_key(steps)
        if shape then route = { shape_key = shape, steps = steps } end
    end

    -- evidence_missing
    local has_evidence = type(rec.evidence) == "table"
    if answers == ResultCollector.ANSWERS.UNANSWERED and not has_evidence then
        local before = type(rec.recorded_at) == "string" and rec.recorded_at < M.EVIDENCE_KEPT_FROM
        flag(M.FLAG.EVIDENCE_MISSING, before
            and "unanswered, written before b5f67bc kept an unanswered trial's evidence"
            or "unanswered and no evidence block")
    end

    local has_timing = type(rec.timing) == "table"

    -- The two timing rules are about how a sweep pressed a PAIR. A named route's
    -- gaps were the operator's grid, pressed as written.
    if is_pair and steps and not has_timing then
        if derived.mechanism == CG.MECHANISM.CANCEL and rule.fixed_gap == nil then
            flag(M.FLAG.LINK_TIMING_ON_CANCEL_PAIR,
                 "a cancel-only pair pressed at the link gap, after A had recovered (be1c0be)")
        end
        local mt = Timing.motion_ticks(steps[2].notation)
        derived.b_motion_ticks = mt
        if mt and mt > 0 then
            flag(M.FLAG.MOTION_BUTTON_LATE,
                 ("B's button came %d tick(s) after the recorded delay: one tick per direction (be1c0be)")
                    :format(mt))
        end
    end

    -- File rules.
    for _, f in ipairs(rule.flags or {}) do flag(f, rule.why) end

    if rule.superseded_by and fc.successor then
        local line = fc.successor[M.rerun_key(rec)]
        if line then
            flag(M.FLAG.SUPERSEDED_RERUN,
                 ("re-run as %s line %d: %s"):format(rule.superseded_by, line, rule.why))
        end
    end

    local supersedes
    if fc.predecessor and fc.predecessor.index then
        local line = fc.predecessor.index[M.rerun_key(rec)]
        if line then
            supersedes = { source_file = fc.predecessor.source_file, line_no = line }
        end
    end

    -- unplayable_input
    if steps then
        local all_known = true
        for _, s in ipairs(steps) do
            if s.kind ~= SequenceCompiler.DRIVE_RUSH_STEP and type(s.notation) ~= "string" then
                all_known = false
            end
        end
        -- A step with no notation cannot be judged, and not judged is not playable.
        if all_known then
            local found = SequenceCompiler.unplayable({ steps = steps }, { context_known = context_known })
            if #found > 0 then
                local kinds, why = {}, {}
                for i, f in ipairs(found) do kinds[i] = f.kind; why[i] = f.reason end
                derived.unplayable = kinds
                flag(M.FLAG.UNPLAYABLE_INPUT, table.concat(why, "; "))
            end
        end
    end

    derived.flag_reasons = next(reasons) and reasons or nil

    local damage = has_evidence and type(rec.evidence.damage) == "table" and rec.evidence.damage or nil
    local measured = damage and int_or_nil(damage.combo_damage) or nil
    if measured and measured < 0 then measured = nil end

    -- The other two things a judged trial records about what the combo DID, and
    -- the only other two: the hit count DamageTracker kept beside the damage,
    -- and the Drive / Super gauges at both ends of the observation window
    -- (RunnerFsm writes evidence.gauges; it does not say which end is a spend
    -- and which is a gain, and neither does this). Carried, not interpreted -
    -- ce.verified_combo.v1 needs them and there was nowhere for them to travel.
    --
    -- This adds no flag and changes no rule, so M.VERSION is NOT bumped: every
    -- evaluation over the committed logs keeps the evidence set, and therefore
    -- the id, it already has.
    local measured_hits = damage and int_or_nil(damage.hits) or nil
    if measured_hits and measured_hits < 0 then measured_hits = nil end

    local g = has_evidence and type(rec.evidence.gauges) == "table" and rec.evidence.gauges or nil
    local gauges = g and {
        drive_start = num_or_nil(g.drive_start), drive_end = num_or_nil(g.drive_end),
        super_start = num_or_nil(g.super_start), super_end = num_or_nil(g.super_end),
    } or nil
    -- A gauges block whose every reading failed is not a reading.
    if gauges and gauges.drive_start == nil and gauges.drive_end == nil
        and gauges.super_start == nil and gauges.super_end == nil then
        gauges = nil
    end

    return {
        kind = "run",
        source_file = fc.source_file,
        line_no = fc.line_no,
        record_id = rec.id,
        schema = rec.schema,
        character = character,
        control_scheme = scheme,
        game_patch = provenance.game_patch,
        calibration_id = provenance.calibration_id,
        context = context,
        recorded_subject_kind = recorded.kind,
        recorded_subject_id = recorded.id,
        subject_kind = subject.kind,
        subject_id = subject.id,
        test_kind = is_pair and M.TEST_KIND.PAIR_LINK or M.TEST_KIND.FULL_COMBO,
        route = route,
        attempt = attempt,
        delays = delays,
        swept_gap = int_or_nil(rec.swept_gap),
        verdict = rec.verdict,
        answers = answers,
        status = rec.status,
        conclusive = (answers ~= ResultCollector.ANSWERS.UNANSWERED),
        runtime_verified = (type(rec.runtime_verified) == "boolean") and rec.runtime_verified or nil,
        measured_damage = measured,
        measured_hits = measured_hits,
        measured_gauges = gauges,
        has_evidence = has_evidence,
        has_timing = has_timing,
        reason = rec.reason,
        recorded_at = rec.recorded_at,
        started_at_frame = int_or_nil(rec.started_at_frame),
        quality_flags = sorted_keys(flags),
        supersedes = supersedes,
        derived = derived,
    }
end

-- --- the pair lookup from a generator run ------------------------------------------

-- edges    : the generator's plain candidate edges
-- excluded : the generator's exclusions ({ from, to, reason, to_notation, ... })
-- key_of   : pipeline.edge_pair_key
--
-- Returns key -> info for M.row's lookup.pair. An exclusion carries ids but no
-- input methods, so it is keyed by the ids and found for every method pair -
-- which is what it says: the generator ruled out A -> B.
function M.pair_index(edges, excluded, key_of)
    local by_key, by_ids = {}, {}
    for _, e in ipairs(edges or {}) do
        by_key[key_of(e)] = {
            status = "candidate",
            mechanism = CG.mechanism(e),
            context_known = e.context_known == true,
            a_notation = e.from and e.from.notation,
            b_notation = e.to and e.to.notation,
        }
    end
    for _, x in ipairs(excluded or {}) do
        if type(x.from) == "number" and type(x.to) == "number" then
            local k = ("%d->%d"):format(x.from, x.to)
            -- No notations: an exclusion does not say which input method its
            -- notation was spelled for, so M.row asks the catalog by method.
            by_ids[k] = by_ids[k] or { status = "excluded", exclusion = x.reason }
        end
    end
    return function(key)
        if by_key[key] then return by_key[key] end
        local a, b = tostring(key):match("^(%d+):[%w_]+%->(%d+):[%w_]+$")
        if a then return by_ids[a .. "->" .. b] end
        return nil
    end
end

return M
