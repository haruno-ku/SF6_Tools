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
-- For the canonical_status vocabulary and nothing else. This file used to spell
-- the starting value "unverified" while Schema's validator accepted only
-- unresolved / verified / conflicting, so every move record built from a row
-- here was rejected on the way out. Reading the word from the one place that
-- defines it is what stops that happening again.
local Schema = require("func/ComboExplorer/core/Schema")

local M = { name = "ComboExplorer.Catalog" }

M.SCHEMA = "ce.catalog.v1"

-- --- classification vocabulary ----------------------------------------------

M.INPUT_METHODS = { MANUAL = "manual", SIMPLE = "simple", ASSIST = "assist",
                    -- Classic has one way of pressing a move: the six buttons
                    -- and a motion. There is no shortcut button to be a second
                    -- method, so the scheme contributes exactly one.
                    CLASSIC = "classic" }

M.SCHEMES = { MODERN = "modern", CLASSIC = "classic" }

-- The input methods a scheme's rows can carry. A caller filtering by method
-- reads this rather than spelling the names, so asking for "manual" against a
-- classic catalog is a question with a knowable answer instead of an empty
-- result nobody can explain.
M.SCHEME_METHODS = {
    modern  = { M.INPUT_METHODS.MANUAL, M.INPUT_METHODS.SIMPLE, M.INPUT_METHODS.ASSIST },
    classic = { M.INPUT_METHODS.CLASSIC },
}

-- Why a row cannot be probed standalone. Each is a real thing in the data, and
-- each would otherwise be recorded as a move that does not work.
M.EXCLUSION = {
    CLASSIC_ONLY   = "classic_only",     -- control_support says Modern cannot reach it
    MODERN_ONLY    = "modern_only",      -- the mirror, for a classic build
    FOLLOWUP       = "followup",         -- ">" derivation: needs a preceding action
    ASSIST_COMBO   = "assist_combo",     -- only a step inside the auto-combo string
    AC_STATE       = "ac_state",         -- reachable only from a specific action state
    AIR            = "air",              -- not a ground-start move
    THROW          = "throw",
    SYSTEM         = "system",           -- dash, DI, parry, drive rush, stance labels
    NO_INPUT       = "no_input",         -- a pure label, no performable input
    ANY_BUTTON     = "any_button",       -- notation names no concrete strength
    -- The notation is a direction and nothing else: "6", "66", "8". Pressing it
    -- walks, jumps or dashes; it cannot produce an attack, so a trial that
    -- pressed it and saw nothing hit would be recording a link that was never
    -- attempted. 74 classic rows over the 31 catalogs, and none under Modern,
    -- which spells the same entries with a motion_command that ends in a
    -- runtime_common ownership the SYSTEM rule already catches.
    MOVEMENT       = "movement",
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

-- A leading ">" is how the source spells "this comes out of something else".
-- It appears on the classic side whether or not the Modern side repeats it, so
-- it is read here as well as in InputMask.parse.
local function strip_derivation(c)
    return (c:gsub("^%s*>%s*", ""))
end

local function classic_is_followup(classic)
    return type(classic) == "string" and classic:match("^%s*>") ~= nil
end

local function category_from_classic(classic)
    if not classic then return "unknown" end
    -- Classified on what the move IS, with the derivation marker removed. A
    -- ">22+MP" left intact matches neither the motion tests nor the leading-digit
    -- test and comes back "unknown", which is a statement about this classifier
    -- rather than about the move - and 24 rows across seven characters were
    -- being dropped as unclassified for it. Being a derivation is recorded
    -- separately; it decides reachability, not category.
    local c = strip_derivation(classic:upper())
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
-- opts.scheme      : "modern" (default) or "classic"
--
-- WHAT CHANGES UNDER CLASSIC
--
-- The classification does not. `category` has always been read off the CLASSIC
-- display - that is what category_from_classic is - and so has the frame-data
-- join, which looks up row.classic. Those two were already scheme-independent
-- and are untouched here.
--
-- What changes is which display becomes the row's `notation`, and therefore
-- what the row says it would take to press. Under Modern a row is built from
-- motion_command or simple_command, and an entry with neither produces no row
-- at all; under Classic a row is built from classic_command, which the source
-- fills in for every entry of every shipped character. That is why a classic
-- catalog is bigger, and it is a fact about coverage rather than about the
-- scheme being better: the 316 classic_only entries across the 31 catalogs are
-- moves Modern genuinely cannot reach.
--
-- Returns catalog, problems. `problems` is never a reason to stop - it is the
-- list of entries the classifier could not place, which is exactly what should
-- be looked at when a new character is added.
function M.build(decoded, opts)
    opts = opts or {}
    local scheme = opts.scheme or M.SCHEMES.MODERN
    if scheme ~= M.SCHEMES.MODERN and scheme ~= M.SCHEMES.CLASSIC then
        return nil, { { reason = ("unknown control scheme %q"):format(tostring(scheme)) } }
    end
    local parse_opts = (scheme == M.SCHEMES.CLASSIC) and { scheme = "classic" } or nil
    if type(decoded) ~= "table" then return nil, { { reason = "not a table" } } end

    local meta = decoded._meta
    if type(meta) ~= "table" then
        return nil, { { reason = "no _meta - this is not a command_display catalog" } }
    end

    local catalog = {
        schema = M.SCHEMA,
        -- Which display every row's `notation` came from. Carried on the
        -- catalog because several consumers have to parse that notation back
        -- (Calibration's single-button groups, SequenceCompiler) and the two
        -- vocabularies do not overlap: reading a classic notation with the
        -- Modern tokeniser produces an empty parse, not an error.
        scheme = scheme,
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
            if scheme == M.SCHEMES.CLASSIC then
                -- One row, one way of pressing it. The Modern branch below is
                -- skipped entirely rather than added to: a classic sweep that
                -- also carried the Modern rows would be two experiments in one
                -- worklist, and the trial record has one control_scheme field.
                if classic then
                    candidates[#candidates + 1] =
                        { method = M.INPUT_METHODS.CLASSIC, notation = classic }
                end
            elseif motion then
                candidates[#candidates + 1] = { method = M.INPUT_METHODS.MANUAL, notation = motion }
            end
            if simple and scheme == M.SCHEMES.MODERN then
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

            if #candidates == 0 and scheme == M.SCHEMES.CLASSIC then
                -- The mirror of the Modern case below, and on the shipped data
                -- it never fires: every one of the 3079 entries across the 31
                -- catalogs carries a classic_command display. Written anyway,
                -- because an entry that vanished with no trace looks the same
                -- as one the source never mentioned.
                catalog.unreachable[#catalog.unreachable + 1] = {
                    action_id = action_id,
                    classic = classic,
                    control_support = support,
                    ownership = ownership,
                    reason = (support == "modern_only") and M.EXCLUSION.MODERN_ONLY
                        or M.EXCLUSION.NO_INPUT,
                }
            elseif #candidates == 0 and support ~= "classic_modern" then
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

            if #candidates == 0 and support == "classic_modern" and scheme == M.SCHEMES.MODERN then
                problems[#problems + 1] = {
                    action_id = action_id,
                    reason = "classic_modern but no Modern command form",
                    classic = classic,
                }
            end

            for _, cand in ipairs(candidates) do
                local parsed, perr = InputMask.parse(cand.notation, parse_opts)

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
                    -- Either side is enough. The Modern display often omits the
                    -- ">" that the classic display carries - JP's 960 is
                    -- ">22+LP+HP" against a Modern "22 + light + heavy" - and
                    -- reading only the Modern side let those rows past the
                    -- follow-up gate to be dropped as unclassified instead.
                    followup = (parsed and parsed.followup or false)
                        or classic_is_followup(classic),
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
                if scheme == M.SCHEMES.MODERN and support ~= "classic_modern" then
                    exclusion = M.EXCLUSION.CLASSIC_ONLY
                elseif scheme == M.SCHEMES.CLASSIC and support == "modern_only" then
                    -- The mirror. `classic_only` is NOT an exclusion under
                    -- classic: it is the source saying this scheme is the one
                    -- that can reach the move, which is the opposite statement.
                    exclusion = M.EXCLUSION.MODERN_ONLY
                elseif row.category == "system" then
                    exclusion = M.EXCLUSION.SYSTEM
                elseif not parsed then
                    exclusion = M.EXCLUSION.NO_INPUT
                elseif row.followup then
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
                elseif #parsed.buttons == 0 and not parsed.any_button then
                    -- Last of the positive rules and deliberately so: anything
                    -- above it is a better description of the same row. What is
                    -- left is a notation with directions and no press at all,
                    -- which the leading-digit rule in category_from_classic
                    -- calls a command normal. Kimberly's 908-913 are the sharp
                    -- case - six rows displaying "6", all of them in the
                    -- specials band - and the frame source lists none of them,
                    -- because they are not moves anyone inputs.
                    exclusion = M.EXCLUSION.MOVEMENT
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
                row.canonical_status = Schema.CANONICAL.UNRESOLVED

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
                  canonical_status = Schema.CANONICAL.UNRESOLVED, canonical_action_id = nil }
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
                g.canonical_status = Schema.CANONICAL.CONFLICTING
                g.conflicting_action_ids = g.conflicting_action_ids or { g.canonical_action_id }
                g.conflicting_action_ids[#g.conflicting_action_ids + 1] = obs.action_id
            elseif g.canonical_status == Schema.CANONICAL.CONFLICTING then
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
                g.canonical_status = Schema.CANONICAL.VERIFIED
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

-- Every action id that shares a notation with this one.
--
-- WHY A TRIAL EXPECTS A GROUP AND NOT AN ID
--
-- A notation names a move as the player sees it, and this catalog gives several
-- ids the same notation - thirteen such groups on Zangief, which is what Probe
-- D's "ambiguous notation groups" counts. Which member comes out depends on
-- context: measured on build 24176760, "2 + SP" is 900 from a standing
-- character and 903 mid-combo.
--
-- A trial that expects one id therefore records a combo that connected as
-- "move B never appeared; saw action id(s) 903 instead". Measured twice: 19 of
-- 30 rows in the #48 route run, and then 105 of 216 in the sweep - in both
-- cases the majority verdict of the whole run, and in both cases wrong.
--
-- action_id_canonical resolves a group to one id and is not wrong; it measured
-- what the button produces from standing. Which member comes out mid-combo is a
-- different question nobody has measured, so the group is what a trial accepts
-- and the narrower question stays open.
--
-- An id the catalog does not have comes back as itself: the caller asked about
-- something, and answering with an empty list would turn "unknown" into
-- "expects nothing", which matches everything.
--
-- WHICH GROUP, WHEN AN ID IS IN MORE THAN ONE
--
-- An id is in one group per way of pressing it, and the groups are not the same
-- size: on Zangief 901 is [901] as "2 + AUTO + SP" and [901, 1497] as
-- "弱 + 中 + 强". This used to return whichever group pairs() reached first, and
-- pairs() over string keys is ordered differently from one Lua process to the
-- next - so which ids a trial accepted could change between two sessions on the
-- same build, with nothing in the record to say so. A test caught it failing
-- one run in five.
--
-- `how` is { input_method, notation }: what the caller is actually pressing,
-- which names exactly one group. Without it, or when that group does not hold
-- the id, the answer is every group the id is in, merged and sorted - wider
-- than any one of them, but the same answer every time.
function M.group_ids(catalog, action_id, how)
    if type(catalog) ~= "table" or type(action_id) ~= "number" then
        return { action_id }
    end
    local groups = catalog.groups or {}

    local function holds(g)
        for _, id in ipairs(g.action_ids or {}) do
            if id == action_id then return true end
        end
        return false
    end

    if type(how) == "table" and how.input_method ~= nil and how.notation ~= nil then
        local g = groups[tostring(how.input_method) .. "|" .. tostring(how.notation)]
        if g and holds(g) then
            local out = {}
            for _, id in ipairs(g.action_ids) do out[#out + 1] = id end
            return out
        end
    end

    local seen, out = {}, {}
    for _, g in pairs(groups) do
        if holds(g) then
            for _, id in ipairs(g.action_ids) do
                if not seen[id] then seen[id] = true; out[#out + 1] = id end
            end
        end
    end
    if #out == 0 then return { action_id } end
    table.sort(out)
    return out
end

return M
