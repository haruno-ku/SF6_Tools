-- =========================================================
-- ComboExplorer/core/KnowledgeDb.lua - adapts verified Explorer results into the
-- shape the sf6-knowledge-db project accepts. Pure: records in, plain Lua tables
-- out. No sdk, no json, no yaml, no paths.
-- =========================================================
--
-- WHY AN ADAPTER AND NOT A SHARED SCHEMA
--
-- The Explorer's records exist to survive a brute-force sweep: they carry
-- evidence, calibration ids, trial counts and a status machine. The target's
-- records exist to be authored by hand in YAML and rendered on a website. If
-- either became the other's persistence format, every change to one would break
-- the other, and the pressure would always be to widen the target until a
-- half-measured Explorer row could sit in it. So the two shapes never touch:
-- this module reads one and builds the other, field by named field.
--
-- NOTHING UNVERIFIED CROSSES
--
-- The target abolished its `placeholder` source kind - domain.ts SOURCE_KINDS is
-- five values and that is not one of them. There is no longer any receptacle for
-- provisional data over there, which means "export it anyway and fix it later"
-- is not an option that exists. A record crosses only when it is
-- status = verified, runtime_verified, carries evidence, carries a MEASURED
-- damage figure, and was measured on the patch and calibration being exported
-- for. Anything else goes to the rejected list with its reason attached,
-- because a record that is silently dropped is a result nobody knows was lost.
--
-- A PREDICTION IS NOT A MEASUREMENT
--
-- Scoring.predicted_damage is an unscaled frame-table sum used to order
-- candidates; the target's outcomes.damage is documented in domain.ts as the
-- value measured in training mode. They are different quantities and only one of
-- them exists here. This module never reads offline_score at all, refuses a
-- record whose measured block carries a `predicted_*` key, and never derives
-- `difficulty` from execution_cost - Scoring says in its own header that
-- difficulty needs a measured window which does not exist yet.
--
-- MISSING SLUGS ARE WORK, NOT ERRORS
--
-- steps[].move names a slug in the target's moves.yaml, and this repository
-- cannot know that mapping, so it is injected. An action id with no slug does
-- not vanish and does not stop the rest of the export: its combo is rejected
-- with the ids named, and the ids themselves accumulate in `missing_moves`,
-- which is the list of moves somebody has to add to moves.yaml.
--
-- WHY TOKEN REPLACEMENT IS BOUNDARY-AWARE
--
-- The catalog's display strings use Chinese strength tokens plus AUTO / SP /
-- THROW, and none of those may reach a display name. Replacing them blindly
-- would be worse than leaving them: "SPD" would become "SpecialD", and a
-- Japanese move name containing the medium character would come out with an "M"
-- in the middle of a word. So a token counts as a token only when what surrounds
-- it is a separator or the end of the string - the same reasoning
-- Catalog.has_system_token uses to stop "DI" firing inside "DIVE". A token that
-- survives conversion is refused and said out loud in the rejected list, never
-- emitted.
--
-- THE VOCABULARIES ARE COPIES, AND SAY SO
--
-- The lists below are transcribed from shared/types/domain.ts. They are copied
-- rather than derived because this is Lua and that is TypeScript, and a copy
-- that names its original can be re-checked while a guess cannot. validate.ts
-- REJECTS unknown keys under requirements and outcomes, so those two blocks are
-- built from a whitelist - and an unrecognised key is reported rather than
-- quietly dropped, because a dropped requirement is a lie about what the combo
-- needs.
--
-- NO YAML
--
-- Everything returned here is a plain Lua table. Serialising, ordering keys and
-- writing files belong to whoever calls this.

local Schema = require("func/ComboExplorer/core/Schema")

local M = { name = "ComboExplorer.KnowledgeDb" }

-- Named so a reader can re-check the copies below against the original.
M.TARGET = {
    types     = "sf6-knowledge-db/scripts/types.ts",
    domain    = "sf6-knowledge-db/shared/types/domain.ts",
    validator = "sf6-knowledge-db/scripts/validate.ts",
}

-- --- the target vocabulary ---------------------------------------------------

M.CONTROL_SCHEMES    = { "classic", "modern" }
M.INPUT_METHODS      = { "manual", "simple", "assist" }
-- One value wider than INPUT_METHODS: a single input cannot be mixed, a whole
-- combo can.
M.INPUT_STYLES       = { "manual", "simple", "assist", "hybrid" }
M.POSITIONS          = { "midscreen", "corner", "anywhere" }
M.COUNTER_CONDITIONS = { "none", "counter", "punish_counter" }
M.KNOCKDOWN_TYPES    = { "none", "soft", "hard", "crumple", "wall_splat", "air_reset" }
M.DISTANCE_CLASSES   = { "near", "mid", "far" }
-- Five kinds, and `placeholder` is deliberately not among them: it was removed
-- from the target, which is why unverified data now has nowhere to go.
M.SOURCE_KINDS       = { "official", "wiki", "video", "community", "self_tested" }
-- The only kind an Explorer result can honestly claim. A training-mode
-- measurement has no URL, which is why the target makes that field optional.
M.EXPLORER_SOURCE_KIND = "self_tested"

M.REQUIREMENT_KEYS = { "drive_min", "sa_min", "position", "counter", "resources" }
M.OUTCOME_KEYS     = { "damage", "drive_spent", "drive_gain", "sa_gain", "resources" }
M.END_STATE_KEYS   = { "advantage_frames", "knockdown_type", "back_rise_allowed",
                       "ends_in_corner", "side_switch", "distance_class" }
M.COMBO_KEYS       = { "slug", "name_ja", "control_scheme", "input_style", "route_group",
                       "difficulty", "requirements", "outcomes", "end_state", "steps",
                       "result_node", "notes", "published", "source" }
M.STEP_KEYS        = { "move", "input_method", "notes" }

local function set_of(list)
    local s = {}
    for _, v in ipairs(list) do s[v] = true end
    return s
end

local IS = {
    control_scheme = set_of(M.CONTROL_SCHEMES),
    input_method   = set_of(M.INPUT_METHODS),
    position       = set_of(M.POSITIONS),
    counter        = set_of(M.COUNTER_CONDITIONS),
    knockdown_type = set_of(M.KNOCKDOWN_TYPES),
    distance_class = set_of(M.DISTANCE_CLASSES),
    requirement    = set_of(M.REQUIREMENT_KEYS),
    end_state      = set_of(M.END_STATE_KEYS),
}

-- The three end-state fields that are genuinely boolean. Listed because `false`
-- is a MEASUREMENT here - "this combo does not switch sides" - and has to be
-- exported, while nil means nobody looked. Collapsing the two would turn a gap
-- into a claim.
local END_STATE_BOOLEAN = set_of({ "back_rise_allowed", "ends_in_corner", "side_switch" })

-- --- why a record did not cross ----------------------------------------------

M.REASON = {
    CONTEXT              = "export_context_incomplete",
    INVALID_RECORD       = "invalid_record",
    NOT_VERIFIED         = "not_verified",
    NOT_RUN              = "not_run_on_the_game",
    NO_EVIDENCE          = "no_evidence",
    PATCH_MISMATCH       = "game_patch_mismatch",
    CALIBRATION_MISMATCH = "calibration_id_mismatch",
    NOT_REPRODUCED       = "not_reproduced",
    DAMAGE_NOT_MEASURED  = "damage_not_measured",
    PREDICTION           = "prediction_where_a_measurement_belongs",
    NO_STEPS             = "no_steps",
    INVALID_STEP         = "invalid_step",
    MOVE_SLUG_MISSING    = "move_slug_missing",
    NOTATION_TOKEN       = "notation_token_in_display_text",
    UNKNOWN_VALUE        = "value_not_in_target_vocabulary",
    UNKNOWN_KEY          = "key_not_in_target_schema",
    NOT_A_NUMBER         = "not_a_number",
    NOT_A_BOOLEAN        = "not_a_boolean",
    OUT_OF_RANGE         = "out_of_range",
    MISSING_FIELD        = "required_field_not_known",
    CHARACTER_MISMATCH   = "character_mismatch",
    SLUG                 = "slug_not_derivable",
    RESOURCE             = "resource_not_exportable",
    ROUTE_GROUP_CONFLICT = "route_group_already_claimed",
}

-- --- display text ------------------------------------------------------------

-- What each catalog token becomes in display text. The three strength characters
-- map the way InputMask.TOKENS already says they do, so that part is the
-- catalog's own equivalence rather than an invention. AUTO / SP / THROW have no
-- established short form that is not itself a token, so they are spelled out; a
-- caller with better names - Japanese ones, for instance - overrides the table.
-- A token mapped to `false` means the caller has declared there is no acceptable
-- rendering, which is a refusal, not a licence to emit it raw.
M.DISPLAY_TOKENS = {
    ["\229\188\177"] = "L",                            -- light
    ["\228\184\173"] = "M",                            -- medium
    ["\229\188\186"] = "H",                            -- heavy
    ["\231\169\186\228\184\173"] = "j.",               -- in the air
    ["\228\187\187\230\132\143\233\148\174"] = "any",  -- any button
    ["AUTO"]  = "Assist",
    ["SP"]    = "Special",
    ["THROW"] = "Throw",
}

-- Longest first, and not only for the usual shadowing reason: the air token ENDS
-- with the medium-strength character, so converting the short one first would
-- leave half an air token behind.
M.TOKEN_ORDER = {
    "\228\187\187\230\132\143\233\148\174",
    "\231\169\186\228\184\173",
    "THROW",
    "AUTO",
    "SP",
    "\229\188\177",
    "\228\184\173",
    "\229\188\186",
}

-- What may sit either side of a token for it to count as one. Anything else - a
-- letter, a digit, another multi-byte character - means the token is part of a
-- longer word and must not be touched.
local BOUNDARY = "[%s%+%-<>%(%)%[%],%./:~]"

local function is_boundary(c)
    return c == "" or c:match(BOUNDARY) ~= nil
end

-- Replaces only boundary-delimited occurrences. Returns the new string and how
-- many were replaced, so the same walk also answers "is it still in there?".
local function replace_token(s, tok, repl)
    local out, from, n = {}, 1, 0
    while true do
        local i, j = s:find(tok, from, true)
        if not i then break end
        local prev = (i > 1) and s:sub(i - 1, i - 1) or ""
        if is_boundary(prev) and is_boundary(s:sub(j + 1, j + 1)) then
            out[#out + 1] = s:sub(from, i - 1)
            out[#out + 1] = repl
            n = n + 1
        else
            out[#out + 1] = s:sub(from, j)
        end
        from = j + 1
    end
    out[#out + 1] = s:sub(from)
    return table.concat(out), n
end

-- text      : any string a person in the target project will read
-- overrides : per-call additions to M.DISPLAY_TOKENS; `false` refuses a token
--
-- Returns the converted text, or nil and a problem naming the token that could
-- not be converted. Refusing is the point: a catalog token in a display name
-- puts a byte sequence nobody outside this repository can read into somebody
-- else's database.
function M.display_name(text, overrides)
    if type(text) ~= "string" or text == "" then
        return nil, { why = "there is no display text to convert" }
    end

    local map = {}
    for k, v in pairs(M.DISPLAY_TOKENS) do map[k] = v end
    for k, v in pairs(overrides or {}) do map[k] = v end

    local out = text
    for _, tok in ipairs(M.TOKEN_ORDER) do
        local repl = map[tok]
        if type(repl) == "string" then out = replace_token(out, tok, repl) end
    end

    for _, tok in ipairs(M.TOKEN_ORDER) do
        local _, left = replace_token(out, tok, "")
        if left > 0 then
            -- false and nil are different answers: one is a decision, the other
            -- is a gap. Both refuse, and the reader is told which.
            local repl = map[tok]
            return nil, {
                token = tok,
                why = (repl == false)
                    and "the caller declared no acceptable rendering for this token"
                    or "no rendering is defined for this token",
            }
        end
    end

    out = out:gsub("%s+", " "):match("^%s*(.-)%s*$")
    if out == "" then return nil, { why = "nothing was left after conversion" } end
    return out
end

-- --- slugs -------------------------------------------------------------------

-- The target's SLUG_RE, spelled out: Lua patterns have no grouped repetition, so
-- the three ways a kebab slug goes wrong are checked one at a time.
function M.is_slug(s)
    if type(s) ~= "string" or s == "" then return false end
    if s:find("[^a-z0-9%-]") then return false end
    if s:sub(1, 1) == "-" or s:sub(-1) == "-" then return false end
    if s:find("%-%-") then return false end
    return true
end

local function slugify(s)
    if type(s) ~= "string" then return nil end
    local out = s:lower():gsub("[^a-z0-9]+", "-")
    out = out:gsub("^%-+", ""):gsub("%-+$", "")
    if out == "" then return nil end
    return out
end
M.slugify = slugify

-- --- the export context ------------------------------------------------------

-- Routes may arrive as a list or as a map keyed by id, because the runtime
-- writes one and the offline pipeline the other. Both are indexed the same way.
local function route_index(routes)
    local idx = {}
    if type(routes) ~= "table" then return idx end
    for k, r in pairs(routes) do
        if type(r) == "table" then
            if r.id ~= nil then idx[r.id] = r end
            if type(k) == "string" then idx[k] = r end
        end
    end
    return idx
end

-- Everything the caller has to supply before a single record can be judged.
-- action_slugs is required as a table even when it is empty: a caller who forgot
-- it would otherwise be told every move in the game needs adding to moves.yaml,
-- which is a plausible-looking answer to a question nobody asked.
local function context(opts)
    opts = opts or {}
    local problems = {}
    local function need(field, why)
        problems[#problems + 1] = { field = field, problem = why }
    end

    local ctx = {
        character = slugify(opts.character),
        game_patch = opts.game_patch,
        calibration_id = opts.calibration_id,
        game_version = opts.game_version,
        action_slugs = opts.action_slugs,
        move_names = opts.move_names or {},
        display_tokens = opts.display_tokens,
        resource_codes = opts.resource_codes,
        routes = route_index(opts.routes),
        source = opts.source,
    }

    if not M.is_slug(ctx.character or "") then
        need("character", "a combos file lives in data/characters/<slug>/, so the "
            .. "character slug is required")
    end
    if ctx.game_patch == nil then
        need("game_patch", "the patch being exported for, so a record measured on "
            .. "another one can be told apart from this one")
    end
    if ctx.calibration_id == nil then
        need("calibration_id", "the calibration being exported for; an action id "
            .. "measured under another one is not evidence about this one")
    end
    if type(ctx.game_version) ~= "string" or ctx.game_version == "" then
        need("game_version", "combos.yaml carries a version code that has to name a "
            .. "row in the target's game_versions.yaml")
    end
    if type(ctx.action_slugs) ~= "table" then
        need("action_slugs", "the action_id -> moves.yaml slug table is injected; this "
            .. "repository cannot know it, and treating it as empty would report every "
            .. "move as unregistered")
    end
    if ctx.source ~= nil and not M.is_slug(ctx.source) then
        need("source", "source names a slug in the target's sources.yaml")
    end

    if #problems > 0 then return nil, problems end
    return ctx
end

-- --- small helpers -----------------------------------------------------------

local function reject(rec, reason, detail, extra)
    local r = {
        id = (type(rec) == "table") and rec.id or nil,
        route_id = (type(rec) == "table") and rec.route_id or nil,
        reason = reason,
        detail = detail,
    }
    for k, v in pairs(extra or {}) do r[k] = v end
    return r
end

local function note_unknown(aux, key, why)
    aux.unknowns[#aux.unknowns + 1] = { key = key, why = why }
end

local function count(list)
    local n = 0
    for _ in ipairs(list or {}) do n = n + 1 end
    return n
end

-- --- the gate ----------------------------------------------------------------

-- Checked in the order the promise is made, so the reason a reader sees is the
-- most fundamental thing wrong rather than whichever check happened to run.
local function gate(rec, ctx)
    if type(rec) ~= "table" then
        return reject(nil, M.REASON.INVALID_RECORD, "not a table")
    end
    if rec.schema ~= Schema.KIND.COMBO then
        return reject(rec, M.REASON.INVALID_RECORD,
            ("expected %s, got %s"):format(Schema.KIND.COMBO, tostring(rec.schema)))
    end
    if rec.status ~= Schema.STATUS.VERIFIED then
        return reject(rec, M.REASON.NOT_VERIFIED,
            ("status is %s. The target has had no receptacle for provisional data "
             .. "since the placeholder source kind was abolished."):format(tostring(rec.status)))
    end
    if rec.runtime_verified ~= true then
        return reject(rec, M.REASON.NOT_RUN,
            "runtime_verified is not true, so this was never run on Street Fighter 6")
    end
    if type(rec.evidence) ~= "table" or next(rec.evidence) == nil then
        return reject(rec, M.REASON.NO_EVIDENCE,
            "a verified record carries the trial it came from, and an empty block is not one")
    end

    -- Before the structural check, not after. Schema.validate also refuses a
    -- verified combo carrying no damage figure, but it can only say "invalid
    -- record"; the caller needs to be told that what is missing is the
    -- measurement, because that is the thing somebody has to go and take.
    local m = rec.measured
    if type(m) ~= "table" then
        return reject(rec, M.REASON.DAMAGE_NOT_MEASURED, "there is no measured block")
    end
    for k in pairs(m) do
        if type(k) == "string" and k:match("^predicted") then
            return reject(rec, M.REASON.PREDICTION,
                ("measured.%s is an offline prediction. Predicted damage is an unscaled "
                 .. "frame-table sum; outcomes.damage is a training-mode measurement."
                 ):format(k))
        end
    end
    if type(m.damage) ~= "number" then
        return reject(rec, M.REASON.DAMAGE_NOT_MEASURED,
            "the target documents outcomes.damage as the value measured in training "
            .. "mode, and no measured figure is present")
    end
    if m.damage < 0 then
        return reject(rec, M.REASON.OUT_OF_RANGE,
            ("measured damage is %s"):format(tostring(m.damage)))
    end

    local ok, problems = Schema.validate(Schema.KIND.COMBO, rec)
    if not ok then
        return reject(rec, M.REASON.INVALID_RECORD,
            "not a valid ce.verified_combo.v1", { problems = problems })
    end

    local p = rec.provenance
    if p.game_patch ~= ctx.game_patch then
        return reject(rec, M.REASON.PATCH_MISMATCH,
            ("measured on %s, exporting for %s"):format(tostring(p.game_patch),
                                                        tostring(ctx.game_patch)))
    end
    if p.calibration_id ~= ctx.calibration_id then
        return reject(rec, M.REASON.CALIBRATION_MISMATCH,
            ("measured under %s, exporting for %s"):format(tostring(p.calibration_id),
                                                           tostring(ctx.calibration_id)))
    end

    -- Known-unstable excludes, and says so with the record's own counts nearby.
    -- Unknown does not: nobody having recorded whether it reproduced is not
    -- evidence that it did not.
    if rec.stable == false and rec.unstable_ok ~= true then
        return reject(rec, M.REASON.NOT_REPRODUCED,
            "the trial did not reproduce, and the record does not knowingly accept that")
    end

    return nil
end

-- --- the blocks --------------------------------------------------------------

-- requirements is authored to mean exactly the target's requirements block, so a
-- key that is not in it is a mistake worth reporting. Silently dropping one
-- would ship a combo claiming to need less than it does.
local function build_requirements(rec, route, ctx, aux)
    local req = {}

    local pos = rec.position or (route and route.position)
    if type(rec.requirements) == "table" and rec.requirements.position ~= nil then
        pos = rec.requirements.position
    end
    if pos ~= nil then
        if not IS.position[pos] then
            return nil, reject(rec, M.REASON.UNKNOWN_VALUE,
                ("position %q is not midscreen | corner | anywhere"):format(tostring(pos)),
                { field = "requirements.position" })
        end
        req.position = pos
    else
        note_unknown(aux, "requirements.position",
            "no position was recorded, and \"anywhere\" would be a claim rather than a gap")
    end

    local ctr = rec.counter or (route and route.counter)
    if type(rec.requirements) == "table" and rec.requirements.counter ~= nil then
        ctr = rec.requirements.counter
    end
    if ctr ~= nil then
        if not IS.counter[ctr] then
            return nil, reject(rec, M.REASON.UNKNOWN_VALUE,
                ("counter %q is not none | counter | punish_counter"):format(tostring(ctr)),
                { field = "requirements.counter" })
        end
        req.counter = ctr
    else
        note_unknown(aux, "requirements.counter", "no counter condition was recorded")
    end

    local given = rec.requirements
    if given ~= nil then
        if type(given) ~= "table" then
            return nil, reject(rec, M.REASON.UNKNOWN_KEY, "requirements is not a table")
        end
        for k, v in pairs(given) do
            if not IS.requirement[k] then
                return nil, reject(rec, M.REASON.UNKNOWN_KEY,
                    ("requirements.%s is not a key the target accepts, and validate.ts "
                     .. "rejects unknown keys there"):format(tostring(k)),
                    { field = "requirements." .. tostring(k) })
            end
            if k == "drive_min" or k == "sa_min" then
                if type(v) ~= "number" then
                    return nil, reject(rec, M.REASON.NOT_A_NUMBER,
                        ("requirements.%s must be a number"):format(k),
                        { field = "requirements." .. k })
                end
                req[k] = v
            elseif k == "resources" then
                if type(v) ~= "table" then
                    return nil, reject(rec, M.REASON.RESOURCE,
                        "requirements.resources must be a table of code -> minimum held")
                end
                local res, problem = {}, nil
                for code, amount in pairs(v) do
                    if type(amount) ~= "number" then
                        problem = reject(rec, M.REASON.NOT_A_NUMBER,
                            ("requirements.resources.%s must be a number"):format(tostring(code)))
                    elseif ctx.resource_codes ~= nil and not ctx.resource_codes[code] then
                        problem = reject(rec, M.REASON.RESOURCE,
                            ("%q is not a declared resource for %s"):format(tostring(code),
                                                                            ctx.character))
                    else
                        res[code] = amount
                    end
                end
                if problem then return nil, problem end
                if next(res) ~= nil then req.resources = res end
            end
        end
    end

    if next(req) == nil then return nil, nil end
    return req, nil
end

-- outcomes is assembled from named fields rather than passed through, because
-- the Explorer's measured block legitimately carries more than the target wants
-- - hit counts, tick counts, both damage arms - and validate.ts rejects any key
-- it does not know.
local function build_outcomes(rec, ctx, aux)
    local m = rec.measured
    local out = { damage = m.damage }

    -- The frame source calls it super gain and the target calls it sa_gain. Both
    -- spellings are read; only the target's name is ever written.
    local wanted = {
        { key = "drive_spent", from = { "drive_spent" } },
        { key = "drive_gain",  from = { "drive_gain" } },
        { key = "sa_gain",     from = { "sa_gain", "super_gain" } },
    }
    for _, w in ipairs(wanted) do
        local v = nil
        for _, name in ipairs(w.from) do
            if m[name] ~= nil then v = m[name] break end
        end
        if v == nil then
            note_unknown(aux, "outcomes." .. w.key, "not measured on this trial")
        elseif type(v) ~= "number" then
            return nil, reject(rec, M.REASON.NOT_A_NUMBER,
                ("outcomes.%s must be a number"):format(w.key),
                { field = "outcomes." .. w.key })
        else
            out[w.key] = v
        end
    end

    if m.resources ~= nil then
        if type(m.resources) ~= "table" then
            return nil, reject(rec, M.REASON.RESOURCE, "measured.resources must be a table")
        end
        local res, problem = {}, nil
        for code, delta in pairs(m.resources) do
            if type(delta) ~= "number" then
                problem = reject(rec, M.REASON.NOT_A_NUMBER,
                    ("outcomes.resources.%s must be a number"):format(tostring(code)))
            elseif ctx.resource_codes ~= nil and not ctx.resource_codes[code] then
                problem = reject(rec, M.REASON.RESOURCE,
                    ("%q is not a declared resource for %s"):format(tostring(code),
                                                                    ctx.character))
            else
                res[code] = delta
            end
        end
        if problem then return nil, problem end
        if next(res) ~= nil then out.resources = res end
    end

    return out, nil
end

-- The six post-combo fields, and only when they were measured. Every one of them
-- is a runtime unknown in Schema.RUNTIME_UNKNOWNS, so an absent field stays
-- absent - and a measured `false` is exported as false, which is why each value
-- is copied through an explicit nil check instead of an `and`/`or` expression
-- that would drop it.
local function build_end_state(rec, aux)
    local es = rec.measured.end_state
    if es == nil then
        note_unknown(aux, "end_state", "no post-combo state was measured")
        return nil, nil
    end
    if type(es) ~= "table" then
        return nil, reject(rec, M.REASON.UNKNOWN_KEY, "measured.end_state is not a table")
    end

    local out = {}
    for k, v in pairs(es) do
        if not IS.end_state[k] then
            return nil, reject(rec, M.REASON.UNKNOWN_KEY,
                ("end_state.%s is not a field the target has"):format(tostring(k)),
                { field = "end_state." .. tostring(k) })
        elseif END_STATE_BOOLEAN[k] then
            if type(v) ~= "boolean" then
                return nil, reject(rec, M.REASON.NOT_A_BOOLEAN,
                    ("end_state.%s must be true or false; it is what was observed"):format(k),
                    { field = "end_state." .. k })
            end
            out[k] = v
        elseif k == "advantage_frames" then
            if type(v) ~= "number" then
                return nil, reject(rec, M.REASON.NOT_A_NUMBER,
                    "end_state.advantage_frames must be a number",
                    { field = "end_state.advantage_frames" })
            end
            out[k] = v
        elseif k == "knockdown_type" then
            if not IS.knockdown_type[v] then
                return nil, reject(rec, M.REASON.UNKNOWN_VALUE,
                    ("knockdown_type %q is not in the target vocabulary"):format(tostring(v)),
                    { field = "end_state.knockdown_type" })
            end
            out[k] = v
        elseif k == "distance_class" then
            if not IS.distance_class[v] then
                return nil, reject(rec, M.REASON.UNKNOWN_VALUE,
                    ("distance_class %q is not near | mid | far"):format(tostring(v)),
                    { field = "end_state.distance_class" })
            end
            out[k] = v
        end
    end

    if next(out) == nil then return nil, nil end
    return out, nil
end

-- --- one record --------------------------------------------------------------

-- rec  : a ce.verified_combo.v1
-- opts : see context()
--
-- Returns combo, rejection, aux. Exactly one of the first two is non-nil, and
-- `aux` comes back either way - a combo rejected FOR a missing move slug still
-- has to hand back the ids that were missing.
function M.combo(rec, opts)
    local aux = { missing = {}, unknowns = {} }

    local ctx, problems = context(opts)
    if not ctx then
        return nil, reject(rec, M.REASON.CONTEXT,
            "the export was asked for without everything needed to judge a record",
            { problems = problems }), aux
    end

    local refusal = gate(rec, ctx)
    if refusal then return nil, refusal, aux end

    -- Steps live on the route: the combo record says which route it measured.
    -- The route either travels inline or is looked up by id, but there is only
    -- ever one route shape, so the two halves cannot drift apart.
    local route = (type(rec.route) == "table") and rec.route or ctx.routes[rec.route_id]
    local steps = route and route.steps
    if type(steps) ~= "table" or count(steps) == 0 then
        return nil, reject(rec, M.REASON.NO_STEPS,
            ("route %s has no steps to name moves from"):format(tostring(rec.route_id))), aux
    end

    local character = slugify(rec.character or (route and route.character))
    if character == nil then
        note_unknown(aux, "character",
            "the record does not name its character, so it is being taken on the "
            .. "caller's word that it belongs in this file")
    elseif character ~= ctx.character then
        return nil, reject(rec, M.REASON.CHARACTER_MISMATCH,
            ("record is about %s, exporting %s"):format(character, ctx.character)), aux
    end

    local scheme = rec.control_scheme or (route and route.control_scheme)
    if scheme == nil then
        return nil, reject(rec, M.REASON.MISSING_FIELD,
            "control_scheme is required by the target and the record does not say"), aux
    end
    if not IS.control_scheme[scheme] then
        return nil, reject(rec, M.REASON.UNKNOWN_VALUE,
            ("control_scheme %q is not classic | modern"):format(tostring(scheme)),
            { field = "control_scheme" }), aux
    end

    -- --- steps ---------------------------------------------------------------

    local out_steps, slug_parts, methods = {}, {}, {}
    local missing_here = {}

    for i, s in ipairs(steps) do
        if type(s) ~= "table" or s.action_id == nil then
            return nil, reject(rec, M.REASON.INVALID_STEP,
                ("step %d names no action id"):format(i)), aux
        end
        local method = s.input_method
        if not IS.input_method[method] then
            return nil, reject(rec, M.REASON.UNKNOWN_VALUE,
                ("step %d input_method %q is not manual | simple | assist"
                 ):format(i, tostring(method)),
                { field = ("steps[%d].input_method"):format(i) }), aux
        end

        -- A table loaded from JSON has string keys and one built in Lua has
        -- numbers. Both spellings are tried rather than making the caller care.
        local slug = ctx.action_slugs[s.action_id] or ctx.action_slugs[tostring(s.action_id)]
        if type(slug) ~= "string" or not M.is_slug(slug) then
            missing_here[#missing_here + 1] = {
                action_id = s.action_id,
                input_method = method,
                -- The raw notation travels with it: whoever adds this move to
                -- moves.yaml needs what the catalog actually says, not only a
                -- cleaned-up rendering of it.
                notation = s.notation,
                classic = s.classic,
                display = M.display_name(s.notation or s.classic, ctx.display_tokens),
                category = s.category,
            }
        else
            slug_parts[#slug_parts + 1] = slug
        end

        local step = { move = slug, input_method = method }
        if s.notes ~= nil then
            local text, problem = M.display_name(s.notes, ctx.display_tokens)
            if not text then
                return nil, reject(rec, M.REASON.NOTATION_TOKEN,
                    ("step %d notes could not be rendered: %s"):format(i, problem.why),
                    { field = ("steps[%d].notes"):format(i), token = problem.token }), aux
            end
            step.notes = text
        end
        out_steps[#out_steps + 1] = step
        methods[method] = (methods[method] or 0) + 1
    end

    -- Every unmapped id in this combo, not just the first: the point of the list
    -- is that one pass tells somebody everything they have to add.
    if #missing_here > 0 then
        local ids = {}
        for k, entry in ipairs(missing_here) do
            ids[k] = tostring(entry.action_id)
            aux.missing[#aux.missing + 1] = entry
        end
        return nil, reject(rec, M.REASON.MOVE_SLUG_MISSING,
            ("no moves.yaml slug for action id(s) %s"):format(table.concat(ids, ", ")),
            { action_ids = ids }), aux
    end

    -- The steps are the record of what was performed, so the style is computed
    -- from them and a supplied one is not consulted. A combo tagged simple that
    -- actually needed a motion input is the exact lie validate.ts exists to
    -- catch, and it cannot happen if the tag is derived.
    local distinct, only = 0, nil
    for method in pairs(methods) do
        distinct = distinct + 1
        only = method
    end
    -- The target describes hybrid as simple mixed with manual. An assist mixed
    -- with anything is still not one method, and hybrid is the only value in the
    -- vocabulary that is not a lie about it.
    local input_style = (distinct == 1) and only or "hybrid"

    -- --- identity ------------------------------------------------------------

    local slug = rec.export_slug
    if slug == nil then
        -- Scheme and style are in the slug because the target resolves siblings
        -- on them: the same moves performed two ways are two rows.
        local parts = { ctx.character, scheme, input_style }
        for _, p in ipairs(slug_parts) do parts[#parts + 1] = p end
        slug = slugify(table.concat(parts, "-"))
    end
    if not M.is_slug(slug or "") then
        return nil, reject(rec, M.REASON.SLUG,
            ("%q is not a kebab-case slug"):format(tostring(slug))), aux
    end

    local name_source = rec.name_ja or rec.name
    if name_source == nil then
        local names = {}
        for _, s in ipairs(steps) do
            names[#names + 1] = tostring(ctx.move_names[s.action_id]
                or ctx.move_names[tostring(s.action_id)]
                or s.notation or s.classic or s.action_id)
        end
        name_source = table.concat(names, " > ")
    end
    local name_ja, name_problem = M.display_name(name_source, ctx.display_tokens)
    if not name_ja then
        return nil, reject(rec, M.REASON.NOTATION_TOKEN,
            ("the display name could not be rendered: %s"):format(name_problem.why),
            { field = "name_ja", token = name_problem.token }), aux
    end

    -- --- the blocks ----------------------------------------------------------

    local requirements, req_problem = build_requirements(rec, route, ctx, aux)
    if req_problem then return nil, req_problem, aux end

    local outcomes, out_problem = build_outcomes(rec, ctx, aux)
    if out_problem then return nil, out_problem, aux end

    local end_state, es_problem = build_end_state(rec, aux)
    if es_problem then return nil, es_problem, aux end

    if rec.stable == nil then
        note_unknown(aux, "stable",
            "nobody recorded whether the trial reproduced, which is a gap, not a failure")
    end

    -- Difficulty is a human judgement in the target. It is never derived from
    -- Scoring.execution_cost, which is a prediction about how much there is to do
    -- and says in its own header that it is not difficulty.
    local difficulty = rec.difficulty
    if difficulty ~= nil then
        if type(difficulty) ~= "number" or difficulty % 1 ~= 0
            or difficulty < 1 or difficulty > 5 then
            return nil, reject(rec, M.REASON.OUT_OF_RANGE,
                "difficulty must be a whole number from 1 to 5",
                { field = "difficulty" }), aux
        end
    else
        note_unknown(aux, "difficulty",
            "difficulty needs the measured execution window, which nothing has measured")
    end

    local notes_parts = {}
    if rec.notes ~= nil then
        local text, problem = M.display_name(rec.notes, ctx.display_tokens)
        if not text then
            return nil, reject(rec, M.REASON.NOTATION_TOKEN,
                ("notes could not be rendered: %s"):format(problem.why),
                { field = "notes", token = problem.token }), aux
        end
        notes_parts[#notes_parts + 1] = text
    end
    -- The YAML has nowhere else to say which run a number came from, and a figure
    -- nobody can trace back to a calibration is a figure nobody can re-check.
    notes_parts[#notes_parts + 1] = ("Measured on %s under calibration %s."):format(
        tostring(ctx.game_patch), tostring(ctx.calibration_id))

    -- --- assembly ------------------------------------------------------------
    --
    -- result_node is deliberately absent. It points into the knowledge graph,
    -- which is authored in the target project; inventing a slug here would fail
    -- validate.ts with a dangling reference. `published` is absent for the
    -- opposite reason: the gate above has already decided this row is real, and
    -- the target's default is to publish.
    local combo = {
        slug = slug,
        name_ja = name_ja,
        control_scheme = scheme,
        input_style = input_style,
        route_group = (type(rec.route_group) == "string") and rec.route_group or nil,
        difficulty = difficulty,
        requirements = requirements,
        outcomes = outcomes,
        end_state = end_state,
        steps = out_steps,
        notes = table.concat(notes_parts, " "),
        source = ctx.source,
    }
    return combo, nil, aux
end

-- --- the whole export --------------------------------------------------------

-- records : ce.verified_combo.v1 records, in any state
-- opts    : see context()
--
-- Returns the result table, or nil and the problems when the caller did not
-- supply enough to judge anything at all. The rejected list is part of the
-- result rather than an error: a record that did not cross is exactly the thing
-- somebody will want to look at.
function M.export(records, opts)
    local ctx, problems = context(opts)
    if not ctx then
        return nil, { reason = M.REASON.CONTEXT, problems = problems }
    end

    local combos, rejected, unknowns, collisions = {}, {}, {}, {}
    local missing, missing_order = {}, {}
    local by_reason, unknown_by_key = {}, {}
    local claimed_slug, claimed_group = {}, {}

    for _, rec in ipairs(records or {}) do
        local combo, why, aux = M.combo(rec, opts)
        local rec_id = (type(rec) == "table") and rec.id or nil

        for _, entry in ipairs(aux.missing) do
            local seen = missing[entry.action_id]
            if not seen then
                entry.wanted_by = {}
                missing[entry.action_id] = entry
                missing_order[#missing_order + 1] = entry
                seen = entry
            end
            seen.wanted_by[#seen.wanted_by + 1] = rec_id
        end
        for _, u in ipairs(aux.unknowns) do
            unknowns[#unknowns + 1] = { id = rec_id, key = u.key, why = u.why }
            unknown_by_key[u.key] = (unknown_by_key[u.key] or 0) + 1
        end

        if combo then
            -- Two routes built from the same moves under the same scheme and
            -- style do collide, and a duplicate slug fails validate.ts.
            -- Suffixed rather than dropped, and the rename is reported.
            if claimed_slug[combo.slug] then
                local n, candidate = 2, nil
                repeat
                    candidate = combo.slug .. "-" .. n
                    n = n + 1
                until not claimed_slug[candidate]
                collisions[#collisions + 1] = { wanted = combo.slug, used = candidate,
                                                id = rec_id }
                combo.slug = candidate
            end
            claimed_slug[combo.slug] = true

            -- The target resolves siblings on route_group + scheme + style and
            -- refuses an ambiguous set, so the second claimant is turned away
            -- here, where its id can still be named.
            if combo.route_group ~= nil then
                local key = ("%s/%s/%s"):format(combo.route_group, combo.control_scheme,
                                                combo.input_style)
                local first = claimed_group[key]
                if first then
                    why = reject(rec, M.REASON.ROUTE_GROUP_CONFLICT,
                        ("%q is already claimed for %s/%s by %s"):format(combo.route_group,
                            combo.control_scheme, combo.input_style, tostring(first)))
                    combo = nil
                else
                    claimed_group[key] = rec_id or combo.slug
                end
            end
        end

        if combo then
            combos[#combos + 1] = combo
        else
            rejected[#rejected + 1] = why
            by_reason[why.reason] = (by_reason[why.reason] or 0) + 1
        end
    end

    return {
        -- CombosFileYaml: a version code that has to name a row in the target's
        -- game_versions.yaml, and the combos themselves.
        file = { version = ctx.game_version, combos = combos },
        character = ctx.character,
        combos = combos,
        rejected = rejected,
        missing_moves = missing_order,
        unknowns = unknowns,
        slug_collisions = collisions,
        counts = {
            exported = #combos,
            rejected = #rejected,
            missing_moves = #missing_order,
            by_reason = by_reason,
            unknown_by_key = unknown_by_key,
        },
    }
end

-- --- the source entry --------------------------------------------------------

-- The sources.yaml row every exported combo points at. Only one kind is
-- available: the Explorer's numbers come from running the game, and any other
-- kind would be a claim about where the data came from that is not true.
function M.source_entry(opts)
    opts = opts or {}
    local kind = opts.kind or M.EXPLORER_SOURCE_KIND
    if kind ~= M.EXPLORER_SOURCE_KIND then
        return nil, ("an Explorer result is %s, not %q. The placeholder kind the target "
            .. "once had is gone, so there is no kind for provisional data either"
            ):format(M.EXPLORER_SOURCE_KIND, tostring(kind))
    end
    if not M.is_slug(opts.slug or "") then
        return nil, "a source needs a kebab-case slug"
    end
    if type(opts.name) ~= "string" or opts.name == "" then
        return nil, "a source needs a name; validate.ts requires it"
    end
    return {
        slug = opts.slug,
        name = opts.name,
        kind = M.EXPLORER_SOURCE_KIND,
        retrieved_on = opts.retrieved_on,
        -- No url, deliberately. There is no page to cite for a training-mode
        -- measurement, which is why the target makes that field optional.
        notes = opts.notes,
    }
end

return M
