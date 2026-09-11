-- =========================================================
-- ComboExplorer/core/CandidateGenerator.lua - proposes A -> B pairs worth
-- trying on the real game. Pure: catalog in, candidate edges out.
-- =========================================================
--
-- WHAT A CANDIDATE IS
--
-- A reason to spend a trial. Nothing here is evidence that a link works, and
-- every edge leaves as `theoretical` with a list of what only the game can
-- settle. The frame table is a shortlist, not a verdict.
--
-- MISSING DATA IS NOT A NEGATIVE ANSWER
--
-- This is the rule the module is built around. If the source has no startup for
-- a move - Zangief's 5HP genuinely has none - the pair is still a candidate,
-- marked low confidence with the gap named. Treating absent information as
-- "cannot link" would quietly delete a large part of the interesting space, and
-- it would do it invisibly: the edge simply would not appear, and nobody would
-- know it had been considered.
--
-- A KNOWN negative margin is different. "A recovers seven frames after B could
-- start" is information, not the absence of it, and such a pair is excluded -
-- but recorded in the excluded list with the number, so the decision is
-- auditable and a later pass (counter hit, drive rush) can revisit it.
--
-- FOLLOW-UPS ARE EDGES EVEN THOUGH THEY ARE NOT MOVES
--
-- A target-combo derivation cannot be produced from neutral, which is why the
-- catalog marks it non-standalone. But A -> that derivation is a real edge, and
-- the only way the derivation is ever reachable. So a standalone move whose
-- frame data says it cancels into a target combo gets edges to the follow-ups,
-- marked context_dependent.

local Schema = require("func/ComboExplorer/core/Schema")
local FrameData = require("func/ComboExplorer/core/FrameData")

local M = { name = "ComboExplorer.CandidateGenerator" }

M.REASON = {
    FRAME_LINK        = "frame_link",
    CHAIN_CANCEL      = "chain_cancel",
    SPECIAL_CANCEL    = "special_cancel",
    SUPER_CANCEL      = "super_cancel",
    DRIVE_RUSH_CANCEL = "drive_rush_cancel",
    TARGET_COMBO      = "target_combo",
    -- Not a mechanism, a state: the data could not rule the pair in or out, so
    -- it is a candidate on the strength of not being refuted.
    FRAME_DATA_INCOMPLETE = "frame_data_incomplete",
}

M.EXCLUDED = {
    NEGATIVE_MARGIN = "frame_margin_negative",
    NO_REASON       = "no_mechanism_found",
    SELF_NOT_CHAINABLE = "self_pair_without_chain",
}

local U = Schema.RUNTIME_UNKNOWNS
-- The producer names the vocabulary it produces, so a typo here is a nil index
-- rather than a string nobody validates.
local C = Schema.CONFIDENCE

-- --- helpers -----------------------------------------------------------------

local function is_special(row)
    return row.category == "special" or row.category == "od_special"
end

local function is_super(row)
    return row.category == "super" or row.category == "super_art" or row.category == "critical_art"
end

local function is_normal(row)
    return row.category == "normal" or row.category == "command_normal"
end

local function contains(list, v)
    for _, x in ipairs(list) do if x == v then return true end end
    return false
end

-- Several distinct gaps can land under one unknown key - an edge missing
-- from_on_hit, to_startup AND the cancel list has three reasons for
-- CANCEL_WINDOW - so the explanations accumulate instead of the last one
-- winning. Overwriting lost the earlier reasons on 98 of 387 Zangief edges, and
-- the exporter then hoisted one arbitrary survivor as the document-wide
-- definition of what that unknown means.
local function add_unknown(edge, what, why)
    if not contains(edge.requires_runtime_validation, what) then
        edge.requires_runtime_validation[#edge.requires_runtime_validation + 1] = what
    end
    local existing = edge.unknown_detail[what]
    if existing == nil then
        edge.unknown_detail[what] = why
    elseif not existing:find(why, 1, true) then
        edge.unknown_detail[what] = existing .. "; " .. why
    end
end

local function edge_id(a, b)
    return ("%d:%s->%d:%s"):format(a.action_id, a.input_method, b.action_id, b.input_method)
end

-- --- the judgement -----------------------------------------------------------

-- Everything the two frame records say about this pair, without deciding
-- anything. Kept separate so the reasoning is inspectable and testable on its
-- own.
local function assess(a_row, b_row, a_frame, b_frame, opts)
    local out = {
        reasons = {},
        basis = {},
        unknowns = {},
    }

    local a_on_hit = FrameData.on_hit(a_frame)
    local b_startup = FrameData.startup(b_frame)

    out.basis.from_on_hit = a_on_hit
    out.basis.to_startup = b_startup
    out.basis.from_damage = FrameData.damage(a_frame)
    out.basis.to_damage = FrameData.damage(b_frame)

    -- A large on-hit advantage almost always means a knockdown, and a
    -- knockdown's advantage is oki advantage - time before the opponent stands
    -- up - not time to land another hit. Every Zangief move at +18 or better is
    -- a knockdown or a throw.
    --
    -- Nothing in the source distinguishes the two: this character's data has no
    -- knockdown property at all. So it is recorded as a suspicion that lowers
    -- confidence and goes on the runtime list, never as grounds to drop the
    -- pair. A frame table cannot tell a 36-frame knockdown from a 36-frame
    -- advantage, and neither can this module.
    if a_on_hit ~= nil and a_on_hit >= (opts.knockdown_suspicion_frames or 18) then
        out.advantage_may_be_knockdown = true
        out.basis.from_on_hit_suspected_knockdown = true
    end
    if FrameData.has_property(a_frame, "throw") == true then
        out.advantage_may_be_knockdown = true
        out.basis.from_is_throw = true
    end

    -- 1. A plain link: A recovers with enough advantage for B to start.
    if a_on_hit ~= nil and b_startup ~= nil then
        local margin = a_on_hit - b_startup
        out.basis.margin_frames = margin
        if margin >= (opts.margin_cutoff or 0) then
            out.reasons[#out.reasons + 1] = M.REASON.FRAME_LINK
        else
            out.negative_margin = margin
        end
    else
        -- Not "no link" - not enough to say. The pair stays a candidate on the
        -- strength of not having been refuted.
        out.reasons[#out.reasons + 1] = M.REASON.FRAME_DATA_INCOMPLETE
        if a_on_hit == nil then out.unknowns[#out.unknowns + 1] = "from_on_hit" end
        if b_startup == nil then out.unknowns[#out.unknowns + 1] = "to_startup" end
    end

    -- 2. Cancels. Each is a different mechanism and each is named separately,
    -- because a pair that is both a link and a cancel has two ways to work and
    -- a pair that is only a cancel has to be executed differently.
    local function cancel(kind) return FrameData.can_cancel_into(a_frame, kind) end

    if is_normal(b_row) and cancel("chain") == true then
        out.reasons[#out.reasons + 1] = M.REASON.CHAIN_CANCEL
    end
    if is_special(b_row) and cancel("special") == true then
        out.reasons[#out.reasons + 1] = M.REASON.SPECIAL_CANCEL
    end
    if is_super(b_row) and cancel("super") == true then
        out.reasons[#out.reasons + 1] = M.REASON.SUPER_CANCEL
    end
    if cancel("drive_rush") == true then
        out.reasons[#out.reasons + 1] = M.REASON.DRIVE_RUSH_CANCEL
    end
    if b_row.followup and cancel("target_combo") == true then
        out.reasons[#out.reasons + 1] = M.REASON.TARGET_COMBO
    end

    if cancel("special") == nil then out.unknowns[#out.unknowns + 1] = "from_cancel_list" end

    return out
end

-- Confidence is about the REASONING, never about whether the link works. A
-- high-confidence candidate is one whose case rests on numbers that were
-- actually present, not one that is likely to succeed.
local function confidence_of(a)
    if contains(a.reasons, M.REASON.FRAME_DATA_INCOMPLETE) then return C.LOW end

    -- Numbers from a join that had to guess cannot support a confident case,
    -- however clean the arithmetic on top of them looks. Zangief's 63214+KK
    -- resolves to the (Close) variant at startup 10 purely by sort order, while
    -- (Mid) is 23 and (Far) is 54 - three readings that turn the same margin
    -- from +26 into -18.
    if a.frame_join_uncertain then return C.LOW end

    -- A suspected knockdown caps the case: the advantage the reasoning rests on
    -- may not be the kind of advantage that links.
    local capped = a.advantage_may_be_knockdown

    if #a.unknowns > 0 then return C.LOW end

    -- Both halves known and named: A cancels into specials AND B is a special.
    if contains(a.reasons, M.REASON.SPECIAL_CANCEL)
        or contains(a.reasons, M.REASON.SUPER_CANCEL) then
        return capped and C.MEDIUM or C.HIGH
    end

    -- A chain cancel is only half known. The source says the move chains; it
    -- does not say what it chains INTO. Calling that high confidence would
    -- claim knowledge the data does not contain.
    if contains(a.reasons, M.REASON.CHAIN_CANCEL) then return C.MEDIUM end

    local m = a.basis.margin_frames
    if m ~= nil and m >= 3 then return capped and C.MEDIUM or C.HIGH end
    if m ~= nil then return C.MEDIUM end
    return C.LOW
end

-- --- generation --------------------------------------------------------------

-- catalog     : from core/Catalog.lua
-- frame_idx   : from core/FrameData.index, or nil (everything becomes low
--               confidence, and nothing is excluded for lack of numbers)
-- opts.from / opts.to : row filters, as accepted by Catalog.probeable
-- opts.include_followups : also emit A -> follow-up edges (default true)
--
-- Returns { candidates, excluded, stats }.
function M.generate(catalog, frame_idx, opts)
    opts = opts or {}
    if type(catalog) ~= "table" or type(catalog.rows) ~= "table" then
        return nil, "not a catalog"
    end

    local Catalog = require("func/ComboExplorer/core/Catalog")

    local from_rows = Catalog.probeable(catalog, opts.from or {})
    local to_rows = Catalog.probeable(catalog, opts.to or opts.from or {})

    -- Follow-ups are not standalone, so probeable() will not return them - but
    -- they are exactly what a target-combo edge points at.
    local followups = {}
    if opts.include_followups ~= false then
        for _, row in ipairs(catalog.rows) do
            if row.exclusion == "followup" then followups[#followups + 1] = row end
        end
    end

    local provenance = opts.provenance or Schema.provenance({})

    local candidates, excluded = {}, {}
    local stats = { pairs_considered = 0, by_reason = {}, by_confidence = {},
                    by_exclusion = {}, followup_edges = 0 }

    -- Cached as a pair. The match info is not decoration: it is how the join
    -- says it had to guess, and dropping it here is what let an arbitrarily
    -- chosen distance variant's numbers become a frame margin nobody could
    -- argue with.
    local frame_of = {}
    local function frame_for(row)
        local hit = frame_of[row]
        if hit == nil then
            if not frame_idx then
                hit = { rec = false, info = { matched = false, reason = "no frame data loaded" } }
            else
                local rec, info = FrameData.lookup(frame_idx, row.classic)
                hit = { rec = rec or false, info = info }
            end
            frame_of[row] = hit
        end
        return hit.rec ~= false and hit.rec or nil, hit.info
    end

    local function consider(a_row, b_row, context_dependent)
        stats.pairs_considered = stats.pairs_considered + 1

        local a_frame, a_info = frame_for(a_row)
        local b_frame, b_info = frame_for(b_row)
        local a = assess(a_row, b_row, a_frame, b_frame, opts)

        -- If either half's numbers came from a guessed join, the reasoning
        -- built on them is a guess too, whatever the arithmetic says.
        local a_uncertain = FrameData.uncertain(a_info)
        local b_uncertain = FrameData.uncertain(b_info)
        if a_uncertain or b_uncertain then
            a.frame_join_uncertain = true
            a.basis.from_frame_key = a_info and a_info.key
            a.basis.to_frame_key = b_info and b_info.key
            a.basis.frame_join_guessed = true
        end

        -- A move repeated straight into itself only works as a chain - but only
        -- a chain property the source actually STATES may exclude it.
        --
        -- This read `not contains(reasons, CHAIN_CANCEL)`, which is true both
        -- when the source says the move does not chain and when the source says
        -- nothing at all. Running with no frame data took self-pair exclusions
        -- from 9 to 14, deleting 5LP into 5LP and 2LP into 2LP among others:
        -- moves that do chain, removed for want of a record. That is the
        -- corollary this module is built on, broken in its own file.
        if a_row.action_id == b_row.action_id and a_row.input_method == b_row.input_method
            and not contains(a.reasons, M.REASON.CHAIN_CANCEL) then
            local chains = FrameData.can_cancel_into(a_frame, "chain")
            if chains == false then
                excluded[#excluded + 1] = {
                    from = a_row.action_id, to = b_row.action_id,
                    from_notation = a_row.notation, to_notation = b_row.notation,
                    reason = M.EXCLUDED.SELF_NOT_CHAINABLE,
                    basis = a.basis,
                    -- The VALUE that decided it, not a sentence about it. A
                    -- sentence is written whether or not it is true, so a reader
                    -- checking that an exclusion was justified learns nothing
                    -- from one; `false` here means the source stated the move
                    -- does not chain, and nil would mean nobody knew - which is
                    -- not grounds to exclude anything.
                    chain_property = chains,
                    evidence = "the frame source lists this move's cancels and chain is not "
                        .. "among them",
                }
                stats.by_exclusion[M.EXCLUDED.SELF_NOT_CHAINABLE] =
                    (stats.by_exclusion[M.EXCLUDED.SELF_NOT_CHAINABLE] or 0) + 1
                return
            end
            -- chains == nil: unknown. The pair survives, saying so.
            a.self_pair_chain_unknown = true
            if not contains(a.reasons, M.REASON.FRAME_DATA_INCOMPLETE) then
                a.reasons[#a.reasons + 1] = M.REASON.FRAME_DATA_INCOMPLETE
            end
        end

        if #a.reasons == 0 then
            -- Known numbers, and they say no. That is information, so the pair
            -- is excluded WITH the number rather than silently dropped: a later
            -- pass over counter hit or drive rush will want to revisit exactly
            -- these.
            local reason = (a.negative_margin ~= nil)
                and M.EXCLUDED.NEGATIVE_MARGIN or M.EXCLUDED.NO_REASON
            excluded[#excluded + 1] = {
                from = a_row.action_id, to = b_row.action_id,
                from_notation = a_row.notation, to_notation = b_row.notation,
                reason = reason,
                margin_frames = a.negative_margin,
                basis = a.basis,
            }
            stats.by_exclusion[reason] = (stats.by_exclusion[reason] or 0) + 1
            return
        end

        local edge = Schema.new(Schema.KIND.EDGE, {
            id = edge_id(a_row, b_row),
            from = { action_id = a_row.action_id, input_method = a_row.input_method,
                     notation = a_row.notation, classic = a_row.classic,
                     category = a_row.category,
                     canonical_status = a_row.canonical_status },
            to   = { action_id = b_row.action_id, input_method = b_row.input_method,
                     notation = b_row.notation, classic = b_row.classic,
                     category = b_row.category,
                     canonical_status = b_row.canonical_status },
            reasons = a.reasons,
            basis = a.basis,
            confidence = confidence_of(a),
            context_dependent = context_dependent or false,
            requires_runtime_validation = {},
            unknown_detail = {},
            provenance = provenance,
        })

        -- The standing list. None of these is decidable from a frame table, and
        -- spacing alone can break any candidate here.
        add_unknown(edge, U.PUSHBACK_RANGE,
            "the frame source records pushback as null; whether the two moves are still "
            .. "in range after the first is only knowable in game")
        add_unknown(edge, U.MODERN_SCALING,
            "Modern damage and its simple-input reduction appear in no frame table")
        add_unknown(edge, U.INPUT_TIMING,
            "the actual input window is what the sweep exists to measure")

        -- The conditional ones, each with the reason it applies to this pair.
        for _, u in ipairs(a.unknowns) do
            add_unknown(edge, U.CANCEL_WINDOW,
                "the frame source is missing " .. u .. " for this pair")
        end
        if is_special(b_row) or is_super(b_row) then
            add_unknown(edge, U.CANCEL_WINDOW,
                "cancel windows into specials and supers have conditions no frame table lists")
        end
        if a_frame and (a_frame.juggle_start or a_frame.juggle_limit) then
            add_unknown(edge, U.JUGGLE,
                "the first move carries juggle state, which decides what may follow")
        end
        if a.advantage_may_be_knockdown then
            add_unknown(edge, U.KNOCKDOWN,
                "the first move's advantage is large enough to be a knockdown, and a "
                .. "knockdown's advantage is time before the opponent stands up rather "
                .. "than time to land another hit; no property in the source distinguishes them")
        end
        if a.frame_join_uncertain then
            if a_uncertain then
                add_unknown(edge, U.FRAME_DATA_AMBIGUOUS,
                    "for the first move, " .. tostring(FrameData.uncertainty_reason(a_info)))
            end
            if b_uncertain then
                add_unknown(edge, U.FRAME_DATA_AMBIGUOUS,
                    "for the second move, " .. tostring(FrameData.uncertainty_reason(b_info)))
            end
        end
        if a.self_pair_chain_unknown then
            add_unknown(edge, U.CANCEL_WINDOW,
                "whether this move chains into itself is not stated by the source, so the "
                .. "pair is here on the strength of not having been refuted")
        end
        if a_row.canonical_status ~= "verified" or b_row.canonical_status ~= "verified" then
            add_unknown(edge, U.HITBOX,
                "which action id this input actually produces is unresolved, so the move "
                .. "being described may not be the move that comes out")
        end
        if context_dependent then
            add_unknown(edge, U.CANCEL_WINDOW,
                "a target-combo derivation only exists inside its own sequence")
        end

        candidates[#candidates + 1] = edge
        for _, r in ipairs(a.reasons) do
            stats.by_reason[r] = (stats.by_reason[r] or 0) + 1
        end
        stats.by_confidence[edge.confidence] = (stats.by_confidence[edge.confidence] or 0) + 1
        if context_dependent then stats.followup_edges = stats.followup_edges + 1 end
    end

    for _, a_row in ipairs(from_rows) do
        for _, b_row in ipairs(to_rows) do
            consider(a_row, b_row, false)
        end
        for _, f_row in ipairs(followups) do
            consider(a_row, f_row, true)
        end
    end

    stats.candidates = #candidates
    stats.excluded = #excluded
    stats.from_moves = #from_rows
    stats.to_moves = #to_rows

    return { candidates = candidates, excluded = excluded, stats = stats }
end

return M
