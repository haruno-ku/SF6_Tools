-- =========================================================
-- ComboExplorer/core/Catalog.lua - turns a raw command_display table into the
-- Explorer's move catalog. Pure: takes a decoded table, never a path.
-- =========================================================
--
-- WHY THE RAW JSON AND NOT THE SUITE'S OWN READER
--
-- func/ComboTrials/CommandDisplay.lua builds a "slim" map and, in the process,
-- falls back between the two Modern command forms:
--
--     item.commands = { simple = simple or manual, motion = manual or simple }
--     item.simple = nil ; item.motion = nil            -- originals deleted
--
-- So asking that map for a move's "simple" form returns its MOTION string when
-- the move has no one-button shortcut. For Zangief that is around fifty moves
-- that would be credited with a Modern shortcut they do not have.
--
-- The consequence is not a crash. The Explorer would press SP for a move that
-- needs a full motion, nothing would come out, and the trial would be recorded
-- as "these moves do not link" - a confident negative, indistinguishable from a
-- real one. So the catalog is built from the raw entries, and
-- tests/lua/test_catalog.lua reproduces the slim-map transform to prove the
-- difference is real rather than theoretical.
--
-- WHAT IS DELIBERATELY NOT DECIDED HERE
--
-- Several action ids share one notation (601/602, 617/618/619, 605/606,
-- 679/680) and nothing in the data says which one an input actually produces.
-- The catalog groups them and marks the group unverified rather than picking
-- one. Picking would either triple the probe matrix or merge two genuinely
-- different moves, and both failures are silent.

local InputMask = require("func/ComboExplorer/core/InputMask")

local M = { name = "ComboExplorer.Catalog" }

M.SCHEMA = "ce.catalog.v1"

-- --- classification vocabulary ----------------------------------------------

M.INPUT_METHODS = { MANUAL = "manual", SIMPLE = "simple", ASSIST = "assist" }

-- Why a row cannot be probed standalone. Each is a real thing in the data, and
-- each would otherwise be recorded as a move that does not work.
M.EXCLUSION = {
    CLASSIC_ONLY   = "classic_only",     -- control_support says Modern cannot reach it
    FOLLOWUP       = "followup",         -- ">" derivation: needs a preceding action
    ASSIST_COMBO   = "assist_combo",     -- only a step inside the auto-combo string
    AC_STATE       = "ac_state",         -- reachable only from a specific action state
    AIR            = "air",              -- not a ground-start move
    THROW          = "throw",
    SYSTEM         = "system",           -- dash, DI, parry, drive rush, stance labels
    NO_INPUT       = "no_input",         -- a pure label, no performable input
    ANY_BUTTON     = "any_button",       -- notation names no concrete strength
    UNCLASSIFIED   = "unclassified",     -- the classifier had no opinion; NOT a statement about the move
}

-- --- helpers -----------------------------------------------------------------

local function display_of(cmd)
    if type(cmd) ~= "table" then return nil end
    local d = cmd.display
    if type(d) ~= "string" or d == "" then return nil end
    return d
end

local function contains(s, needle)
    return type(s) == "string" and s:find(needle, 1, true) ~= nil
end

-- Category from the CLASSIC notation shape, which is data rather than an
-- assumption about how Capcom numbers actions. The action-id band is recorded
-- alongside it, unused, so a disagreement between the two is visible instead of
-- being silently resolved one way.
-- System actions the catalog names in words rather than in notation. Checked
-- BEFORE the notation shape, because several of them carry a direction prefix
-- ("6+DI") that would otherwise read as a command normal - which is how Drive
-- Impact ends up in a list of ground normals.
local SYSTEM_TOKENS = {
    "DI",        -- Drive Impact
    "DRC",       -- Drive Rush Cancel
    "RAW DR",    -- raw Drive Rush
    "DP",        -- the parry label
    "PARRY",
    "REVERSAL",
    "NORMAL",    -- the neutral-state label on ac_state entries
}

local function has_system_token(c)
    for _, tok in ipairs(SYSTEM_TOKENS) do
        -- Word-ish match: "DI" must not fire on "DIVE", and the notation
        -- vocabulary is small enough that boundary characters are just + and
        -- space.
        if c == tok
            or c:match("^" .. tok .. "[%s%+]")
            or c:match("[%s%+]" .. tok .. "$")
            or c:match("[%s%+]" .. tok .. "[%s%+]") then
            return true
        end
    end
    return false
end

-- A charge motion is written with the held direction in brackets: [4]6 is
-- "hold back, then forward". Zangief has none, which is why the classifier
-- below was written without them and why six characters lost every special they
-- have - see docs/ComboExplorer/catalog-audit.md.
--
-- The super form is the doubled one, by the same shape rule that makes 236236 a
-- super and 236 a special: [4]6 is one cardinal after the charge, [4]646 is
-- three. Read off the notation, not off the action id - the id band is recorded
-- on the row beside this and deliberately does not get a vote, so that a
-- disagreement between the two stays visible.
local function charge_category(c)
    local after = c:match("^%s*%[[1-9]%]([0-9]+)")
    if not after then return nil end
    if #after >= 3 then return "super" end
    if c:match("PP") or c:match("KK") then return "od_special" end
    return "special"
end

local function category_from_classic(classic)
    if not classic then return "unknown" end
    local c = classic:upper()
    if has_system_token(c) then return "system" end
    if c == "N" then return "system" end
    if contains(c, "THROW") or c == "THROW" then return "throw" end

    local charge = charge_category(c)
    if charge then return charge end

    if c:match("^%d*236236") or c:match("^%d*214214") or c:match("^720") then return "super" end
    -- 623 is the dragon punch. It was absent because Zangief has none, and its
    -- absence did not show up as "unknown": 623+HP starts with a digit, so it
    -- fell through to the command-normal branch below and 147 rows across 18
    -- characters were searched as command normals.
    if c:match("236") or c:match("214") or c:match("360") or c:match("63214")
        or c:match("^22") or c:match("^41236") or c:match("623") then
        -- PP / KK is the OD form of the same motion.
        if c:match("PP") or c:match("KK") then return "od_special" end
        return "special"
    end
    if c:match("^J%.") then return "air_normal" end
    if c:match("^%d") then return "command_normal" end
    if c:match("^[LMH][PK]$") then return "normal" end
    return "unknown"
end

local function band_from_action_id(id)
    -- Informational only. Recorded so a later character can be checked against
    -- it, never used to decide anything here.
    if id < 500 then return "system_or_movement" end
    if id < 700 then return "normals" end
    if id < 800 then return "throws" end
    if id < 1100 then return "specials" end
    return "supers"
end

-- --- the build ---------------------------------------------------------------

-- decoded : the parsed contents of command_display/<Char>.json
-- opts.ground_only : drop air rows from `probeable` (default true)
--
-- Returns catalog, problems. `problems` is never a reason to stop - it is the
-- list of entries the classifier could not place, which is exactly what should
-- be looked at when a new character is added.
function M.build(decoded, opts)
    opts = opts or {}
    if type(decoded) ~= "table" then return nil, { { reason = "not a table" } } end

    local meta = decoded._meta
    if type(meta) ~= "table" then
        return nil, { { reason = "no _meta - this is not a command_display catalog" } }
    end

    local catalog = {
        schema = M.SCHEMA,
        source_schema = meta.schema,
        character = meta.character,
        fighter_id = meta.fighter_id,
        generated_at = meta.generated_at,
        -- Carried so a recorded dataset can be invalidated when the game data
        -- behind it changes. An action id measured against one AC/BCM pair is
        -- not evidence about another.
        ac_sha256 = meta.ac_sha256,
        bcm_sha256 = meta.bcm_sha256,
        rows = {},
        groups = {},
        counts = {},
        -- Entries with no Modern form at all. They produce no row - there is no
        -- input to probe - but they must not simply be absent: a move that
        -- vanished from the catalog with no trace looks the same as a move the
        -- source never mentioned, and the difference is the whole question of
        -- whether Modern can reach it.
        unreachable = {},
    }
    local problems = {}

    local entry_count, classic_only = 0, 0

    for key, entry in pairs(decoded) do
        local action_id = tostring(key):match("^(%d+)$")
        if action_id and type(entry) == "table" then
            action_id = tonumber(action_id)
            entry_count = entry_count + 1

            local classic = display_of(entry.classic_command)
            local simple  = display_of(entry.simple_command)
            local motion  = display_of(entry.motion_command)
            local ownership = entry.ownership
            local support = entry.control_support

            if support ~= "classic_modern" then
                classic_only = classic_only + 1
            end

            -- One row per (action_id, input method). The methods are FLAGS, not
            -- an enum: 901/924/945/963 are legitimately both simple and assist,
            -- and each execution path has to be probed separately because they
            -- are different inputs producing the same action.
            local candidates = {}
            if motion then
                candidates[#candidates + 1] = { method = M.INPUT_METHODS.MANUAL, notation = motion }
            end
            if simple then
                -- AUTO is the Assist button; SP is the Special button. A
                -- notation can carry both ("AUTO + SP"), so this is not a
                -- choice between them.
                if contains(simple, "AUTO") then
                    candidates[#candidates + 1] = { method = M.INPUT_METHODS.ASSIST, notation = simple }
                end
                if contains(simple, "SP") then
                    candidates[#candidates + 1] = { method = M.INPUT_METHODS.SIMPLE, notation = simple }
                end
                if not contains(simple, "AUTO") and not contains(simple, "SP") then
                    -- A simple_command that names neither button is not
                    -- something this classifier understands. Recorded rather
                    -- than guessed at.
                    problems[#problems + 1] = {
                        action_id = action_id, reason = "simple_command names neither SP nor AUTO",
                        display = simple,
                    }
                end
            end

            if #candidates == 0 and support ~= "classic_modern" then
                -- The ordinary case for a classic-only move, and the reason the
                -- CLASSIC_ONLY exclusion below almost never fires: an entry with
                -- neither a motion nor a simple command produces no row to
                -- exclude in the first place. Recorded here so the nine Zangief
                -- moves in this state are countable and nameable rather than
                -- silently missing.
                catalog.unreachable[#catalog.unreachable + 1] = {
                    action_id = action_id,
                    classic = classic,
                    control_support = support,
                    ownership = ownership,
                    reason = M.EXCLUSION.CLASSIC_ONLY,
                }
            end

            if #candidates == 0 and support == "classic_modern" then
                problems[#problems + 1] = {
                    action_id = action_id,
                    reason = "classic_modern but no Modern command form",
                    classic = classic,
                }
            end

            for _, cand in ipairs(candidates) do
                local parsed, perr = InputMask.parse(cand.notation)

                local row = {
                    action_id = action_id,
                    input_method = cand.method,
                    notation = cand.notation,
                    classic = classic,
                    control_support = support,
                    ownership = ownership,
                    category = category_from_classic(classic),
                    action_id_band = band_from_action_id(action_id),
                    air = parsed and parsed.air or false,
                    followup = parsed and parsed.followup or false,
                    any_button = parsed and parsed.any_button or false,
                    parse_error = (not parsed) and perr or nil,
                    -- Kept for cross-checking against what the injector builds.
                    -- NOT used to build a mask: the bits themselves are
                    -- unverified, and this field is another party's opinion of
                    -- them, not a measurement.
                    raw_button_mask = nil,
                    route_profile = nil,
                }

                -- Match the route that corresponds to this input method, so the
                -- catalog can later be checked against what the game's own
                -- command table says the button should be.
                for _, r in ipairs(entry.routes or {}) do
                    local is_easy = (r.profile == "easy" or r.profile == "supr")
                    local want_easy = (cand.method ~= M.INPUT_METHODS.MANUAL)
                    if is_easy == want_easy then
                        row.raw_button_mask = r.raw_button_mask
                        row.route_profile = r.profile
                        row.visible_direction = r.visible_direction
                        row.visible_button = r.visible_button
                        break
                    end
                end

                -- Standalone means: can a probe produce this from neutral?
                -- Everything below is a real thing in the data, and every one
                -- of them would otherwise be recorded as a move that does not
                -- link rather than a move that was never performed.
                --
                -- Order is deliberate. Reachability first, then WHAT the action
                -- is, then whether its notation could be parsed. Drive Rush is
                -- written "RAW DR", which carries no performable input, but
                -- calling it "no_input" tells a reader less than calling it a
                -- system action - and this list is read by a human deciding
                -- what to probe next.
                local exclusion = nil
                if support ~= "classic_modern" then
                    exclusion = M.EXCLUSION.CLASSIC_ONLY
                elseif row.category == "system" then
                    exclusion = M.EXCLUSION.SYSTEM
                elseif not parsed then
                    exclusion = M.EXCLUSION.NO_INPUT
                elseif parsed.followup then
                    exclusion = M.EXCLUSION.FOLLOWUP
                elseif ownership == "assist_combo" then
                    exclusion = M.EXCLUSION.ASSIST_COMBO
                elseif type(ownership) == "string" and ownership:match("^ac_state") then
                    exclusion = M.EXCLUSION.AC_STATE
                elseif parsed.any_button then
                    exclusion = M.EXCLUSION.ANY_BUTTON
                elseif parsed.air then
                    exclusion = M.EXCLUSION.AIR
                elseif row.category == "throw" then
                    exclusion = M.EXCLUSION.THROW
                elseif row.category == "system" or ownership == "runtime_common" then
                    exclusion = M.EXCLUSION.SYSTEM
                elseif row.category == "unknown" then
                    -- "The classifier could not place this" is not the same
                    -- statement as "this is a dash". Both used to come out as
                    -- SYSTEM, which turned a gap in our vocabulary into a fact
                    -- about the move - the exact pattern this project exists to
                    -- avoid - and made the loss uncountable, because an
                    -- unclassified row was indistinguishable from a real system
                    -- action in every report downstream.
                    --
                    -- It is still excluded: a row whose category is unknown
                    -- cannot be scored or budgeted. But it is excluded UNDER ITS
                    -- OWN NAME, so `by_exclusion.unclassified` says how much
                    -- vocabulary is missing.
                    exclusion = M.EXCLUSION.UNCLASSIFIED
                end

                row.standalone = (exclusion == nil)
                row.exclusion = exclusion

                -- Notation identity, used to group ids that cannot be told
                -- apart from the data. Grouped on the notation AND the method,
                -- because the same notation under two methods is two inputs.
                row.display_group = cand.method .. "|" .. cand.notation
                row.canonical_status = "unverified"

                catalog.rows[#catalog.rows + 1] = row
            end
        end
    end

    table.sort(catalog.rows, function(a, b)
        if a.action_id ~= b.action_id then return a.action_id < b.action_id end
        return a.input_method < b.input_method
    end)

    -- --- grouping -------------------------------------------------------------
    --
    -- Several action ids share one notation and the data does not say which one
    -- an input produces. The group carries them all with the question open; a
    -- calibration sweep answers it later by observing which id actually comes
    -- out (see M.apply_observations).
    for _, row in ipairs(catalog.rows) do
        local g = catalog.groups[row.display_group]
        if not g then
            g = { display_group = row.display_group, notation = row.notation,
                  input_method = row.input_method, action_ids = {},
                  canonical_status = "unverified", canonical_action_id = nil }
            catalog.groups[row.display_group] = g
        end
        g.action_ids[#g.action_ids + 1] = row.action_id
    end
    for _, g in pairs(catalog.groups) do
        table.sort(g.action_ids)
        g.ambiguous = (#g.action_ids > 1)
    end

    table.sort(catalog.unreachable, function(a, b) return a.action_id < b.action_id end)

    local counts = { entries = entry_count, rows = #catalog.rows, classic_only = classic_only,
                     unreachable = #catalog.unreachable,
                     standalone = 0, excluded = 0, by_method = {}, by_exclusion = {},
                     ambiguous_groups = 0, ambiguous_rows = 0 }
    for _, row in ipairs(catalog.rows) do
        if row.standalone then counts.standalone = counts.standalone + 1
        else
            counts.excluded = counts.excluded + 1
            counts.by_exclusion[row.exclusion] = (counts.by_exclusion[row.exclusion] or 0) + 1
        end
        counts.by_method[row.input_method] = (counts.by_method[row.input_method] or 0) + 1
    end
    for _, g in pairs(catalog.groups) do
        if g.ambiguous then
            counts.ambiguous_groups = counts.ambiguous_groups + 1
            -- The rows, not just the groups. A reader judging how much of the
            -- catalog is still unpinned needs the number of moves affected, and
            -- every ambiguous group holds at least two.
            counts.ambiguous_rows = counts.ambiguous_rows + #g.action_ids
        end
    end
    catalog.counts = counts

    -- Sorted before returning: pairs() over the command_display keys is in hash
    -- order, which Lua 5.4 seeds per process. Without this the report's "could
    -- not place" section lists a different arbitrary subset every run, making
    -- it the one non-reproducible output of a pipeline whose documents are
    -- otherwise byte-identical between runs.
    table.sort(problems, function(a, b)
        local ai, bi = tonumber(a.action_id) or 0, tonumber(b.action_id) or 0
        if ai ~= bi then return ai < bi end
        return tostring(a.reason) < tostring(b.reason)
    end)

    return catalog, problems
end

-- --- queries -----------------------------------------------------------------

-- The rows a standalone A->B sweep can actually use.
--
-- `standalone` is a statement about the DATA: can this action be produced from
-- neutral at all. Scope is a separate question and belongs to the caller.
-- MVP 0 passes input_methods = { "manual" }, because whether pressing
-- Assist+L produces the single move the catalog names or starts the whole
-- auto-combo string is not established - 627 and 660 are marked
-- official_semantic rather than assist_combo, but nothing in the data says what
-- the button actually does from neutral. That is a calibration question, so
-- assist rows stay in the catalog and out of the first sweep.
function M.probeable(catalog, opts)
    opts = opts or {}

    local want_method = nil
    if opts.input_methods then
        want_method = {}
        for _, m in ipairs(opts.input_methods) do want_method[m] = true end
    end

    local out = {}
    for _, row in ipairs(catalog.rows or {}) do
        if row.standalone then
            local ok = true
            if opts.categories then
                ok = false
                for _, c in ipairs(opts.categories) do
                    if row.category == c then ok = true break end
                end
            end
            if ok and want_method and not want_method[row.input_method] then ok = false end
            if ok then out[#out + 1] = row end
        end
    end
    return out
end

function M.excluded(catalog, reason)
    local out = {}
    for _, row in ipairs(catalog.rows or {}) do
        if not row.standalone and (reason == nil or row.exclusion == reason) then
            out[#out + 1] = row
        end
    end
    return out
end

-- Groups where more than one action id shares a notation. These are the ones a
-- calibration sweep has to resolve; until then the catalog refuses to say which
-- id an input produces.
function M.ambiguous_groups(catalog)
    local out = {}
    for _, g in pairs(catalog.groups or {}) do
        if g.ambiguous then out[#out + 1] = g end
    end
    table.sort(out, function(a, b) return a.display_group < b.display_group end)
    return out
end

-- --- resolving the ambiguity from real observations -------------------------

-- observations : { { notation = "...", input_method = "manual", action_id = 621 }, ... }
-- as produced by a calibration sweep - press a known input, record what came out.
--
-- Only ever promotes: an observation that names an id outside its group is
-- recorded as a conflict rather than silently adopted, because an input that
-- produces an unexpected action is a finding, not a correction.
function M.apply_observations(catalog, observations)
    local applied, conflicts = {}, {}

    for _, obs in ipairs(observations or {}) do
        local key = tostring(obs.input_method) .. "|" .. tostring(obs.notation)
        local g = catalog.groups and catalog.groups[key]
        if not g then
            conflicts[#conflicts + 1] = { reason = "no such group", observation = obs }
        else
            local in_group = false
            for _, id in ipairs(g.action_ids) do
                if id == obs.action_id then in_group = true break end
            end
            if not in_group then
                conflicts[#conflicts + 1] = {
                    reason = "observed action id is not in the group for that notation",
                    observation = obs, group_action_ids = g.action_ids,
                }
            elseif g.canonical_action_id ~= nil and g.canonical_action_id ~= obs.action_id then
                conflicts[#conflicts + 1] = {
                    reason = "the same input produced two different action ids",
                    observation = obs, previously = g.canonical_action_id,
                }
                g.canonical_status = "conflicting"
                g.conflicting_action_ids = g.conflicting_action_ids or { g.canonical_action_id }
                g.conflicting_action_ids[#g.conflicting_action_ids + 1] = obs.action_id
            elseif g.canonical_status == "conflicting" then
                -- A disagreement is not undone by the next observation that
                -- happens to agree with the first. If one input has been seen
                -- to produce two action ids, that is what it does, and a run of
                -- matching observations afterwards is not evidence otherwise -
                -- it is a sample that happened to come out one way. Letting
                -- this fall through to the else branch would make the group's
                -- verdict depend on the order the sweep ran in, and would drop
                -- the hitbox_hurtbox unknown off every edge built from it.
                conflicts[#conflicts + 1] = {
                    reason = "observation matches, but this group is already known to conflict",
                    observation = obs, previously = g.canonical_action_id,
                }
            else
                g.canonical_action_id = obs.action_id
                g.canonical_status = "verified"
                applied[#applied + 1] = key
            end
        end
    end

    -- Mirror the group's answer onto its rows so a consumer never has to
    -- consult two places and get two answers.
    for _, row in ipairs(catalog.rows or {}) do
        local g = catalog.groups[row.display_group]
        if g then
            row.canonical_status = g.canonical_status
            -- Written with an explicit branch, not `cond and nil or v`: in Lua
            -- the `and` arm evaluating to nil always falls through to `or`, so
            -- that spelling can never yield nil and would stamp a hard
            -- is_canonical = false onto every row whose group nobody has
            -- observed. False is a measured negative - "this input does not
            -- produce this action id" - and manufacturing one out of an absence
            -- of measurement is the exact thing this project must not do.
            if g.canonical_action_id == nil then
                row.is_canonical = nil          -- nobody has looked
            else
                row.is_canonical = (g.canonical_action_id == row.action_id)
            end
        end
    end

    return applied, conflicts
end

return M
