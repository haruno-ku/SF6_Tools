-- =========================================================
-- ComboExplorer/core/Schema.lua - the shapes every artifact is written in, and
-- the rule that stops an unverified thing from claiming to be verified.
-- Pure. No sdk, no json, no paths.
-- =========================================================
--
-- THE ONE RULE
--
-- Nothing becomes `verified` without having been run on Street Fighter 6. The
-- offline pipeline can produce candidates by the thousand and not one of them
-- is a fact - a frame table saying A recovers before B starts is a reason to
-- try the pair, not evidence that it works.
--
-- That is easy to agree with and easy to lose. Every stage downstream is
-- tempted to promote its own output, and once a `theoretical` row is written to
-- a file as `verified` nothing later can tell the difference. So the status
-- vocabulary is closed, the transitions are one-way, and validate() refuses a
-- verified record that carries no runtime evidence.
--
-- STATUS
--
--   theoretical      generated from data. No game has seen it.
--   runtime_pending  queued for a trial, or a trial is in flight.
--   verified         run on the real game and it worked. Requires evidence.
--   rejected         run on the real game and it did not. Also requires it.
--
-- `rejected` needs evidence for the same reason `verified` does: "we tried it
-- and it failed" and "we never tried it" are different facts, and only the
-- first one should stop anybody re-testing.

local M = { name = "ComboExplorer.Schema" }

M.STATUS = {
    THEORETICAL     = "theoretical",
    RUNTIME_PENDING = "runtime_pending",
    VERIFIED        = "verified",
    REJECTED        = "rejected",
}

local STATUS_SET = {}
for _, v in pairs(M.STATUS) do STATUS_SET[v] = true end

-- Statuses that are claims about the real game, and therefore need evidence.
local RUNTIME_STATUS = {
    [M.STATUS.VERIFIED] = true,
    [M.STATUS.REJECTED] = true,
}

-- What may follow what. Offline output can only ever enter at `theoretical`.
M.TRANSITIONS = {
    [M.STATUS.THEORETICAL]     = { [M.STATUS.RUNTIME_PENDING] = true },
    [M.STATUS.RUNTIME_PENDING] = { [M.STATUS.VERIFIED] = true, [M.STATUS.REJECTED] = true },
    [M.STATUS.VERIFIED]        = { [M.STATUS.RUNTIME_PENDING] = true },  -- re-test after a patch
    [M.STATUS.REJECTED]        = { [M.STATUS.RUNTIME_PENDING] = true },
}

function M.can_transition(from, to)
    if not STATUS_SET[from] or not STATUS_SET[to] then return false, "unknown status" end
    if from == to then return true end
    local allowed = M.TRANSITIONS[from]
    if allowed and allowed[to] then return true end
    return false, ("%s cannot become %s"):format(from, to)
end

-- --- the things that get written ---------------------------------------------

M.KIND = {
    MOVE          = "ce.move.v1",
    EDGE          = "ce.edge.v1",
    ROUTE         = "ce.route.v1",
    TRIAL         = "ce.trial.v1",
    CONFIRMED     = "ce.confirmed_edge.v1",
    COMBO         = "ce.verified_combo.v1",
    CALIBRATION   = "ce.calibration.v1",
    DIAGNOSTICS   = "ce.diagnostics.v1",
}

-- The things a frame table cannot settle. Recorded on every candidate rather
-- than used to reject one: information the source does not carry is not
-- evidence that a link fails, and treating it that way would quietly delete
-- most of the interesting combos.
--
-- Several of these are literally null in the frame data - `pushback` on
-- Zangief's 2MP, for instance - so this list is not speculation about what a
-- source might lack. It is what the source says it does not know.
M.RUNTIME_UNKNOWNS = {
    PUSHBACK_RANGE   = "pushback_range",
    JUGGLE           = "juggle_behaviour",
    HITBOX           = "hitbox_hurtbox",
    CANCEL_WINDOW    = "cancel_window_conditions",
    CHARACTER_RESOURCE = "character_specific_resource",
    CORNER           = "wall_corner_interaction",
    SIDE_SWITCH      = "side_switch",
    MODERN_SCALING   = "modern_specific_scaling",
    INPUT_TIMING     = "actual_input_timing",
    -- Frame advantage after a knockdown is oki advantage, not link advantage.
    -- No property in the frame source distinguishes them - Zangief's data has
    -- no knockdown property at all - so a large on-hit number is a suspicion,
    -- not a fact, and the game has to settle it.
    KNOCKDOWN        = "knockdown_vs_link_advantage",
}

-- Applies to every candidate, whatever the frame table says. Spacing decides
-- whether a link connects at all, the Modern damage reduction is not in any
-- frame table, and the input timing is the thing the sweep exists to measure.
M.ALWAYS_UNKNOWN = {
    M.RUNTIME_UNKNOWNS.PUSHBACK_RANGE,
    M.RUNTIME_UNKNOWNS.MODERN_SCALING,
    M.RUNTIME_UNKNOWNS.INPUT_TIMING,
}

-- --- provenance --------------------------------------------------------------

-- Every artifact says where it came from, because the person reading it is on
-- another machine and cannot ask. An action id measured against one AC/BCM pair
-- is not evidence about another, so the checksums travel with the data.
function M.provenance(opts)
    opts = opts or {}
    return {
        game_patch = opts.game_patch,
        command_display = opts.command_display and {
            character = opts.command_display.character,
            fighter_id = opts.command_display.fighter_id,
            generated_at = opts.command_display.generated_at,
            ac_sha256 = opts.command_display.ac_sha256,
            bcm_sha256 = opts.command_display.bcm_sha256,
            schema = opts.command_display.schema,
        } or nil,
        frame_data = opts.frame_data and {
            source = opts.frame_data.source,
            commit = opts.frame_data.commit,
            url = opts.frame_data.url,
            license = opts.frame_data.license,
            fetched_at = opts.frame_data.fetched_at,
        } or nil,
        calibration_id = opts.calibration_id,
        explorer_version = opts.explorer_version,
        generated_at = opts.generated_at,
    }
end

-- --- validation --------------------------------------------------------------

local function err(problems, field, msg)
    problems[#problems + 1] = { field = field, problem = msg }
end

local function require_fields(obj, fields, problems)
    for _, f in ipairs(fields) do
        if obj[f] == nil then err(problems, f, "required") end
    end
end

-- The check that matters. Everything else here is shape; this is the promise.
local function check_status(obj, problems)
    local st = obj.status
    if st == nil then
        err(problems, "status", "required")
        return
    end
    if not STATUS_SET[st] then
        err(problems, "status", ("unknown status %q"):format(tostring(st)))
        return
    end

    if RUNTIME_STATUS[st] then
        -- A claim about the real game has to name the game it was made on.
        if obj.runtime_verified ~= true then
            err(problems, "runtime_verified",
                ("status %s requires runtime_verified = true"):format(st))
        end
        if type(obj.evidence) ~= "table" then
            err(problems, "evidence",
                ("status %s requires evidence from a real trial"):format(st))
        end
        local p = obj.provenance
        if type(p) ~= "table" or p.calibration_id == nil then
            err(problems, "provenance.calibration_id",
                ("status %s requires the calibration the trial ran under"):format(st))
        end
        if type(p) ~= "table" or p.game_patch == nil then
            err(problems, "provenance.game_patch",
                ("status %s requires the game patch it was measured on"):format(st))
        end
    else
        -- The other direction, and the one that actually goes wrong: an offline
        -- artifact quietly claiming it has been run.
        if obj.runtime_verified == true then
            err(problems, "runtime_verified",
                ("status %s cannot carry runtime_verified = true"):format(st))
        end
    end
end

local VALIDATORS = {}

VALIDATORS[M.KIND.MOVE] = function(o, p)
    require_fields(o, { "action_id", "input_method", "notation", "standalone",
                        "canonical_status" }, p)
    if o.input_method and not ({ manual = true, simple = true, assist = true })[o.input_method] then
        err(p, "input_method", "must be manual, simple or assist")
    end
    if o.canonical_status
        and not ({ unresolved = true, verified = true, conflicting = true })[o.canonical_status] then
        err(p, "canonical_status", "must be unresolved, verified or conflicting")
    end
    if o.standalone == false and o.exclusion == nil then
        err(p, "exclusion", "a non-standalone move must say why")
    end
end

VALIDATORS[M.KIND.EDGE] = function(o, p)
    require_fields(o, { "id", "from", "to", "status", "reasons",
                        "requires_runtime_validation", "provenance" }, p)
    if type(o.reasons) == "table" and #o.reasons == 0 then
        err(p, "reasons", "a candidate must say why it is a candidate")
    end
    if type(o.requires_runtime_validation) == "table" and #o.requires_runtime_validation == 0 then
        -- Not a formality. There is no such thing as an edge a frame table can
        -- fully settle: spacing alone can break any of them.
        err(p, "requires_runtime_validation", "no edge is fully decidable offline")
    end
end

VALIDATORS[M.KIND.ROUTE] = function(o, p)
    require_fields(o, { "id", "steps", "status", "provenance" }, p)
    if type(o.steps) == "table" and #o.steps < 2 then
        err(p, "steps", "a route needs at least two steps")
    end
    if o.offline_score ~= nil and type(o.offline_score) ~= "table" then
        err(p, "offline_score", "must be a table")
    end
    -- Offline predictions and runtime measurements never share a field, so a
    -- prediction can never be mistaken for a measurement later.
    for _, forbidden in ipairs({ "damage", "actual_damage", "execution_leniency_frames" }) do
        if o.offline_score and o.offline_score[forbidden] ~= nil then
            err(p, "offline_score." .. forbidden,
                "measured-sounding name in an offline score; use predicted_* instead")
        end
    end
end

VALIDATORS[M.KIND.TRIAL] = function(o, p)
    require_fields(o, { "id", "edge_id", "status", "verdict", "attempt" }, p)
end

VALIDATORS[M.KIND.CONFIRMED] = function(o, p)
    require_fields(o, { "id", "edge_id", "status", "attempts", "successes", "provenance" }, p)
    if o.status == M.STATUS.VERIFIED and o.stable ~= true and o.unstable_ok ~= true then
        err(p, "stable", "a verified edge must have reproduced, or say it knowingly did not")
    end
end

VALIDATORS[M.KIND.COMBO] = function(o, p)
    require_fields(o, { "id", "route_id", "status", "measured", "provenance" }, p)
    if type(o.measured) == "table" and o.measured.damage == nil then
        err(p, "measured.damage", "a verified combo carries a measured damage figure")
    end
end

VALIDATORS[M.KIND.CALIBRATION] = function(o, p)
    require_fields(o, { "calibration_id", "game_patch", "values" }, p)
end

VALIDATORS[M.KIND.DIAGNOSTICS] = function(o, p)
    require_fields(o, { "probe", "header", "body" }, p)
end

-- Returns ok, problems. `problems` is a list, so a caller can report every
-- failure at once rather than one per run.
function M.validate(kind, obj)
    local problems = {}
    if type(obj) ~= "table" then
        return false, { { field = "(root)", problem = "not a table" } }
    end
    if obj.schema ~= kind then
        err(problems, "schema", ("expected %q, got %q"):format(tostring(kind), tostring(obj.schema)))
    end

    -- Calibration and diagnostics are records of a measurement, not claims
    -- about a move, so the status machinery does not apply to them.
    if kind ~= M.KIND.CALIBRATION and kind ~= M.KIND.DIAGNOSTICS then
        check_status(obj, problems)
    end

    local v = VALIDATORS[kind]
    if v then v(obj, problems) else err(problems, "schema", "no validator for that kind") end

    return #problems == 0, problems
end

-- Convenience for the pipeline: build a record already carrying its schema tag
-- and the offline defaults, so no caller has to remember to set
-- runtime_verified = false.
function M.new(kind, fields)
    local o = { schema = kind, status = M.STATUS.THEORETICAL, runtime_verified = false }
    for k, v in pairs(fields or {}) do o[k] = v end
    return o
end

-- Moves a record along, refusing a transition the vocabulary does not allow and
-- refusing to reach a runtime status without evidence.
function M.transition(obj, to, evidence)
    if type(obj) ~= "table" then return false, "not a record" end
    local ok, why = M.can_transition(obj.status, to)
    if not ok then return false, why end

    if RUNTIME_STATUS[to] then
        if type(evidence) ~= "table" then
            return false, ("%s requires evidence from a real trial"):format(to)
        end
        obj.evidence = evidence
        obj.runtime_verified = true
    end
    obj.status = to
    return true
end

return M
