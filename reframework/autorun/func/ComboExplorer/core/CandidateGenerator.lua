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
--
-- A FOLLOW-UP AFTER A MOVE THAT IS NOT ITS PARENT IS NOT A PAIR
--
-- Every starter used to be crossed with every follow-up: 14 starters and 4
-- derivations made 56 of Zangief's 378 worklist pairs, and 54 of them were
-- ">MP" after 2LP, ">MK" after 6HP - sequences that cannot exist, because a
-- derivation is only ever produced out of the one move it belongs to. The
-- sweep set them aside before the first trial (#49), which kept them from
-- writing false rows but left them in the list, counted as pairs.
--
-- The frame source settles this, and it settles it by statement rather than by
-- silence. It never spells a derivation on its own - ">MP" is only ever
-- "5MP~MP" - so the records ending in "~MP" are the source saying what ">MP"
-- comes out of (FrameData.names_parent). When they name a parent and A is not
-- it, that is known structure, in the same class as a negative margin: the pair
-- is excluded under its own reason, with the parents the source named, and
-- counted.
--
-- It is NOT an exclusion for missing information, and the difference is kept
-- exact. When the source names no parent for a follow-up at all - no chain for
-- that move anywhere in the data, or no frame data loaded - nothing is known
-- about what it follows, and every such pair stays a candidate exactly as
-- before. Only the sweep then sets it aside, for want of anyone vouching for
-- the context.
--
-- An edge whose parent the source DOES name carries context_known = true.
-- That is the vouching SequenceCompiler.unplayable asks for: the worklist
-- carries it, and the sweep plays the pair instead of setting it aside.
--
-- A THROW IS NOT THE SECOND MOVE OF A COMBO
--
-- The route finder's best routes by predicted damage were almost all "X > 720 +
-- 强" - Zangief's SA3, action 1218, 4800 damage - and the trial logs say none of
-- them ever connected. At cancel timing SA3 came out and touched nothing
-- (hits_added 0) after 611, 617, 621 and 655, while the strike super 1206 at the
-- same timing linked. The reason is not the timing: an opponent in hitstun is
-- not throwable, and the frame source tags 720+P, 360+P, 63214K and 236236K
-- `throw`. So those pairs cannot be made to work by any delay, and every trial
-- spent on one was three seconds spent confirming a rule of the game.
--
-- This is a KNOWN structural fact, the same class as a derivation after a move
-- that is not its parent: the source STATES the property, so the pair is
-- excluded under its own reason with the statement attached, not silently
-- dropped. When the record is absent, or present with no properties list, the
-- source says nothing about what kind of move it is - and silence is never
-- grounds to exclude, so the pair stays a candidate exactly as before.
--
-- Only move B. A throw is a perfectly good STARTER: it is what the combo opens
-- with, the opponent is standing in neutral, and every throw remains in the
-- from-set untouched. The rule is about what may follow a hit, and it holds at
-- any depth, because a route is built out of these edges and every step after
-- the first is a B.
--
-- A rush does not rescue it. A -> DRC -> throw is still a throw after a hit, so
-- the Drive Rush pass asks the same question and records the same reason,
-- marked `via` like the rest of that pass.
--
-- DRIVE RUSH CANCEL EDGES: A -> (drive rush) -> B
--
-- Off unless opts.include_drive_rush is set, so every existing output is the
-- same with the option absent. When it is on, a second kind of edge is built
-- beside the plain ones: A is cancelled into a Drive Rush, and B comes out of
-- the rush. It is a different mechanism with a different number, so it is a
-- different edge - id "A->drc->B", `via = "drive_rush_cancel"` - and never a
-- second reason on the plain A -> B edge. A pair that does not link can be a
-- fine DRC pair, and a caller that searches routes over plain edges must not
-- pick up a rush it did not ask for by reading a reason list.
--
-- Which As can do it is read from the source, and read with the same care as
-- everything else here. The fixture generator writes drc_on_hit / drc_on_block
-- only when the source has a Drive Rush Cancel block for the move. So:
--
--   * A's record present with drc_on_hit: a DRC edge, judged on
--     drc_margin = drc_on_hit - B.startup.
--   * A's record present with neither field: the source listing the move and
--     giving it no Drive Rush Cancel. That is a statement - the same class as a
--     cancel list without "chain" in it - and A gets no DRC pairs. It is
--     counted ONCE per move in stats.drc_not_cancelable, not once per B as an
--     exclusion: the source says it once, about the move, and thirty-three
--     copies of one sentence in the excluded list would bury the exclusions
--     that are about pairs.
--   * A's record absent, or joined only by guessing: nothing is known, so every
--     B is still a DRC candidate at low confidence with the gap named. A
--     guessed record's silence is not the move's silence, and unlike a margin
--     exclusion this decision leaves no per-pair record behind to argue with,
--     so a guess may not make it.
--
-- A KNOWN drc_margin below the cutoff excludes, with the number, under its own
-- reason (drc_margin_negative) - the plain frame_margin_negative is a
-- different number about a different sequence.
--
-- A self pair (5LP -> DRC -> 5LP) is allowed. SELF_NOT_CHAINABLE is a rule
-- about chaining a move into itself; the rush in between is exactly what lets
-- the same button come out twice.
--
-- A follow-up is never B after a rush. A derivation only comes out of its
-- parent with nothing in between, and a Drive Rush is in between by
-- definition, so every (A, follow-up) crossing of an A that could rush is
-- excluded under followup_after_drive_rush, once per pair, carrying the
-- catalog's own statement that B is a derivation. Chosen over a bare counter
-- because it is the precedent FOLLOWUP_NOT_AFTER_PARENT set: a pair that was
-- considered and ruled out on structure is in the excluded list where a reader
-- can see it, and it is bounded - starters times follow-ups, 4 follow-ups for
-- Zangief.
--
-- Everything DRC is counted apart from the plain edges: stats.drc_* for edges,
-- confidence and pairs, so by_reason / by_confidence / pairs_considered /
-- candidates / excluded still describe the plain edges alone. The two exclusion reasons DO land in
-- stats.by_exclusion, because every exclusion in the list is counted there -
-- M.DRC_EXCLUSIONS names them so a reader of by_exclusion can tell them apart.
--
-- None of these can be pressed yet. How Drive Rush is input on this build, and
-- which action id a DRC is, are unmeasured (RUNTIME_UNKNOWNS.DRIVE_RUSH).

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
    -- A derivation after a move the frame source says it does not come out of.
    -- Structure, not a gap: see "A FOLLOW-UP AFTER A MOVE THAT IS NOT ITS
    -- PARENT" above for why this is not an exclusion for missing information.
    FOLLOWUP_NOT_AFTER_PARENT = "followup_after_a_move_not_its_parent",
    -- B is a throw, and the opponent A just hit is in hitstun rather than
    -- throwable. Structure, not a gap: see "A THROW IS NOT THE SECOND MOVE OF A
    -- COMBO" above.
    THROW_AFTER_HIT = "throw_after_a_hit",
    -- A -> DRC -> B where the source's drc_on_hit for A leaves B's startup
    -- short. The number travels as drc_margin_frames.
    DRC_MARGIN_NEGATIVE = "drc_margin_negative",
    -- A -> DRC -> a derivation. See "DRIVE RUSH CANCEL EDGES" above.
    FOLLOWUP_AFTER_DRIVE_RUSH = "followup_after_drive_rush",
}

-- The exclusion reasons only the Drive Rush pass produces, so a consumer that
-- reports plain edges can leave them out of its own by_exclusion table.
-- THROW_AFTER_HIT is deliberately not here: both passes produce it, because it
-- is one fact about move B and not a fact about the rush. A reader who needs to
-- tell those apart has M.is_drive_rush on the record itself.
M.DRC_EXCLUSIONS = {
    [M.EXCLUDED.DRC_MARGIN_NEGATIVE] = true,
    [M.EXCLUDED.FOLLOWUP_AFTER_DRIVE_RUSH] = true,
}

-- What a DRC edge and a DRC exclusion carry as `via`.
M.VIA_DRIVE_RUSH = "drive_rush_cancel"

-- True for an edge or an exclusion the Drive Rush pass produced.
function M.is_drive_rush(record)
    return type(record) == "table" and record.via == M.VIA_DRIVE_RUSH
end

-- HOW a plain edge would have to be pressed, in one word, from its reasons.
--
--   "link"   : B after A has recovered - the only reason is frame_link
--   "cancel" : B during A's hit - a chain, special, super or target-combo
--              cancel, and no link margin (a known negative margin is what
--              keeps frame_link off the list)
--   "both"   : a link margin AND a named cancel, so either timing may work
--   "unknown": nothing either way - frame_data_incomplete alone
--
-- frame_data_incomplete beside a cancel counts as both: the link was not
-- refuted, it was not examined. Carried into the worklist because the sweep
-- has to press a cancel at a completely different time from a link, and before
-- this the worklist said neither - so every pair was timed as a link, cancels
-- included (runtime/Sweep.lua, core/Timing.lua).
M.MECHANISM = { LINK = "link", CANCEL = "cancel", BOTH = "both", UNKNOWN = "unknown" }

local CANCEL_REASONS = {
    chain_cancel = true, special_cancel = true, super_cancel = true, target_combo = true,
}

function M.mechanism(edge)
    local reasons = type(edge) == "table" and (edge.reasons or edge) or {}
    local link, cancel, open = false, false, false
    for _, r in ipairs(reasons) do
        if r == M.REASON.FRAME_LINK then link = true
        elseif r == M.REASON.FRAME_DATA_INCOMPLETE then open = true
        elseif CANCEL_REASONS[r] then cancel = true end
    end
    if cancel and (link or open) then return M.MECHANISM.BOTH end
    if cancel then return M.MECHANISM.CANCEL end
    if link then return M.MECHANISM.LINK end
    return M.MECHANISM.UNKNOWN
end

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

-- Does the frame source say this record is a throw? true / false / nil, and nil
-- is the answer that matters: no record, or a record with no properties list, is
-- the source saying nothing, and nothing is never grounds to exclude a pair.
--
-- Two independent statements are accepted, because the source makes it both
-- ways. A normal throw is spelled category "throw" AND properties { "throw" };
-- a command throw - 360+P, 720+P, 63214K, 236236K - is category "special" or
-- "super_art" and carries the property alone. Across the 31 shipped characters
-- no record is category "throw" without the property, so the property covers
-- every case today; the category is read as well so that a source which drops
-- the property from an obvious throw is not read as silence.
--
-- Returns the verdict and the two values it was read from, which travel on the
-- exclusion so a reader can check it against the source rather than trust a
-- sentence.
local function throw_verdict(rec)
    local prop = FrameData.has_property(rec, "throw")
    local category = rec and rec.category or nil
    local is_throw
    if prop == true or category == "throw" then is_throw = true
    elseif prop == false then is_throw = false
    else is_throw = nil end
    return is_throw, prop, category
end

local function edge_id(a, b)
    return ("%d:%s->%d:%s"):format(a.action_id, a.input_method, b.action_id, b.input_method)
end

-- Distinct from edge_id on purpose: the same two moves can be a plain edge and
-- a DRC edge at once, and they are two different sequences.
local function drc_edge_id(a, b)
    return ("%d:%s->drc->%d:%s"):format(a.action_id, a.input_method, b.action_id, b.input_method)
end

-- The frame data stores some numbers as strings. Kept local rather than added
-- to FrameData's accessor list, because these are carried through as evidence
-- rather than reasoned about here.
local function num_or_nil(v)
    if type(v) == "number" then return v end
    if type(v) == "string" then return tonumber(v) end
    return nil
end

-- --- the judgement -----------------------------------------------------------

-- Everything the two frame records say about this pair, without deciding
-- anything. Kept separate so the reasoning is inspectable and testable on its
-- own.
--
-- The numbers about the two moves themselves - what A is and what B needs - are
-- filled by frames_of_pair, which the Drive Rush pass shares. Only the
-- judgement differs between a link and a rush; the evidence carried about the
-- moves must not, or a worklist reader would see two different 5LPs.
local function frames_of_pair(out, a_frame, b_frame, opts)
    local a_on_hit = FrameData.on_hit(a_frame)
    local b_startup = FrameData.startup(b_frame)

    out.basis.from_on_hit = a_on_hit
    out.basis.to_startup = b_startup
    out.basis.from_damage = FrameData.damage(a_frame)
    out.basis.to_damage = FrameData.damage(b_frame)

    -- The rest of A's frames, carried so the worklist can hand core/Timing.lua
    -- enough to predict WHEN a link has to be pressed - not just whether one is
    -- possible.
    --
    -- The margin below answers "can B start before the advantage runs out".
    -- That was the only thing ever written down, and the sweep then ran every
    -- pair at delay 4: a cancel window, never a link window (#46). The gap needs
    -- A's whole animation, hitstop included, because
    -- Provenance.hitstop_advances_tick is REFUTED on this build.
    out.basis.from_startup  = FrameData.startup(a_frame)
    out.basis.from_active   = a_frame and a_frame.active or nil
    out.basis.from_recovery = a_frame and num_or_nil(a_frame.recovery) or nil
    out.basis.from_hitstop  = a_frame and num_or_nil(a_frame.hitstop) or nil
    out.basis.from_hitstun  = a_frame and num_or_nil(a_frame.hitstun) or nil

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

    return a_on_hit, b_startup
end

local function assess(a_row, b_row, a_frame, b_frame, opts)
    local out = {
        reasons = {},
        basis = {},
        unknowns = {},
    }

    local a_on_hit, b_startup = frames_of_pair(out, a_frame, b_frame, opts)

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
    -- There used to be a `cancel("drive_rush")` check here. It could never
    -- fire: no source record lists "drive_rush" among its cancels - the source
    -- says a move can rush by carrying drc_on_hit, not in the cancel list - so
    -- DRIVE_RUSH_CANCEL was a reason no edge had ever been given. A rush is a
    -- sequence of its own, with its own number, and is built as its own edge by
    -- the Drive Rush pass in generate().
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

-- The same judgement for a Drive Rush Cancel edge, on the DRC margin. Kept as
-- its own function rather than a flag on confidence_of because the inputs are
-- not the same: a DRC edge has no cancel reasons to lean on, and its margin is
-- a different number that must never be read from margin_frames.
--
-- Same spirit, same thresholds: an unknown or a guessed join is low; a known
-- margin of 3 or more is high unless a suspected knockdown caps it; a known
-- margin that is thinner than that is medium.
local function drc_confidence_of(a)
    if #a.unknowns > 0 then return C.LOW end
    if a.frame_join_uncertain then return C.LOW end
    local m = a.basis.drc_margin_frames
    if m == nil then return C.LOW end
    if m >= 3 then return a.advantage_may_be_knockdown and C.MEDIUM or C.HIGH end
    return C.MEDIUM
end

-- --- generation --------------------------------------------------------------

-- catalog     : from core/Catalog.lua
-- frame_idx   : from core/FrameData.index, or nil (everything becomes low
--               confidence, and nothing is excluded for lack of numbers)
-- opts.from / opts.to : row filters, as accepted by Catalog.probeable
-- opts.include_followups : also emit A -> follow-up edges (default true)
-- opts.include_drive_rush : also emit A -> DRC -> B edges (default false). They
--               are appended to `candidates` / `excluded` after every plain
--               record and carry `via = "drive_rush_cancel"`; see the header.
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
                    by_exclusion = {}, followup_edges = 0,
                    -- Of followup_edges, how many the source vouches for. The
                    -- rest are follow-ups whose parent it never names.
                    followup_parent_named = 0 }

    -- Cached as a pair. The match info is not decoration: it is how the join
    -- says it had to guess, and dropping it here is what let an arbitrarily
    -- chosen distance variant's numbers become a frame margin nobody could
    -- argue with.
    local frame_of = {}
    local frame_of_pair = {}

    -- `after` is the row this one comes out of, when the caller knows it. Only
    -- move B of an edge has one; move A is being produced from neutral.
    --
    -- Two caches, not one, and that is forced rather than chosen. The source
    -- spells a derivation as a chain from its parent ("5MK~MK"), so the same B
    -- row genuinely has DIFFERENT numbers after different As - which is the
    -- fact the old single-row cache could not hold. A row with no parent still
    -- uses the row cache, so the common path is unchanged.
    local function frame_for(row, after)
        local key, store = row, frame_of
        if after ~= nil then
            local per_a = frame_of_pair[after]
            if per_a == nil then per_a = {} frame_of_pair[after] = per_a end
            key, store = row, per_a
        end

        local hit = store[key]
        if hit == nil then
            if not frame_idx then
                hit = { rec = false, info = { matched = false, reason = "no frame data loaded" } }
            else
                local rec, info = FrameData.lookup(frame_idx, row.classic,
                    { after = after and after.classic or nil, band = row.action_id_band })
                hit = { rec = rec or false, info = info }
            end
            store[key] = hit
        end
        return hit.rec ~= false and hit.rec or nil, hit.info
    end

    -- Per follow-up row, not per pair: which parents the source names depends
    -- on B alone, and the scan is over every key in the index.
    local parents_of = {}

    local function consider(a_row, b_row, context_dependent)
        stats.pairs_considered = stats.pairs_considered + 1

        -- Before any arithmetic, because none applies: a derivation after a
        -- move that is not its parent is not a slow link or a short one, it is
        -- a sequence that cannot be produced. See the header.
        --
        -- Three outcomes, and only one excludes. `false` is the source naming
        -- this follow-up's parents and A not being among them. `nil` - no
        -- parent named anywhere, or no frame data at all - is silence, and the
        -- pair goes on to be judged exactly as it always was.
        local context_known = nil
        local parent_hit = nil
        if context_dependent and frame_idx then
            local parents = parents_of[b_row]
            if parents == nil then
                parents = FrameData.derivation_parents(frame_idx, b_row.classic)
                parents_of[b_row] = parents
            end
            local named, _, hit = FrameData.names_parent(frame_idx, b_row.classic,
                                                         a_row.classic, parents)
            if named == false then
                local spelled = {}
                for _, p in ipairs(parents) do spelled[#spelled + 1] = p.key end
                excluded[#excluded + 1] = {
                    from = a_row.action_id, to = b_row.action_id,
                    from_notation = a_row.notation, to_notation = b_row.notation,
                    reason = M.EXCLUDED.FOLLOWUP_NOT_AFTER_PARENT,
                    -- The records that decided it, verbatim. A reader checking
                    -- the exclusion looks these up in the source and finds the
                    -- chains; a sentence would have to be taken on trust.
                    parent_records = spelled,
                    evidence = "the frame source spells this follow-up only as a chain from "
                        .. "its parent, and none of those chains starts with the first move",
                }
                stats.by_exclusion[M.EXCLUDED.FOLLOWUP_NOT_AFTER_PARENT] =
                    (stats.by_exclusion[M.EXCLUDED.FOLLOWUP_NOT_AFTER_PARENT] or 0) + 1
                return
            elseif named == true then
                context_known = true
                parent_hit = hit
            end
        end

        -- A is produced from neutral, so it has no parent to be read against.
        -- B does: in this edge, A is what it comes out of.
        local a_frame, a_info = frame_for(a_row)
        local b_frame, b_info = frame_for(b_row, a_row)

        -- Before any arithmetic, for the same reason as the parent check: a
        -- throw after a hit is not a thin link, it is not a link at all. The
        -- opponent A just hit is in hitstun and cannot be thrown, so no delay
        -- makes this pair work. Only a stated property excludes; a record the
        -- source never wrote is silence and the pair survives it.
        local b_is_throw, b_throw_prop, b_record_category = throw_verdict(b_frame)
        if b_is_throw then
            excluded[#excluded + 1] = {
                from = a_row.action_id, to = b_row.action_id,
                from_notation = a_row.notation, to_notation = b_row.notation,
                reason = M.EXCLUDED.THROW_AFTER_HIT,
                -- The values that decided it, not a sentence about them. `true`
                -- or "throw" means the source stated it; nil would mean nobody
                -- did, and this branch is not reached on nil.
                throw_property = b_throw_prop,
                to_record_category = b_record_category,
                -- Which record was read, so the statement can be looked up.
                to_frame_key = b_info and b_info.key,
                to_frame_join_guessed = FrameData.uncertain(b_info) or nil,
                evidence = "the frame source marks the second move a throw, and a throw "
                    .. "cannot connect after a hit: the opponent is in hitstun, not throwable",
            }
            stats.by_exclusion[M.EXCLUDED.THROW_AFTER_HIT] =
                (stats.by_exclusion[M.EXCLUDED.THROW_AFTER_HIT] or 0) + 1
            return
        end

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
            -- True only when the frame source names A as B's parent. Absent
            -- otherwise, including on a follow-up whose parent nobody names:
            -- absent is "nobody vouched", which is what the sweep needs to hear.
            context_known = context_known,
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
        if parent_hit then
            -- Kept with the edge so "context_known" can be checked against the
            -- record that earned it rather than taken as a flag.
            edge.basis.parent_record = parent_hit.key
        end

        candidates[#candidates + 1] = edge
        for _, r in ipairs(a.reasons) do
            stats.by_reason[r] = (stats.by_reason[r] or 0) + 1
        end
        stats.by_confidence[edge.confidence] = (stats.by_confidence[edge.confidence] or 0) + 1
        if context_dependent then stats.followup_edges = stats.followup_edges + 1 end
        if context_known then stats.followup_parent_named = stats.followup_parent_named + 1 end
    end

    for _, a_row in ipairs(from_rows) do
        for _, b_row in ipairs(to_rows) do
            consider(a_row, b_row, false)
        end
        for _, f_row in ipairs(followups) do
            consider(a_row, f_row, true)
        end
    end

    -- --- the Drive Rush pass ---------------------------------------------------
    --
    -- After the plain loop and appended, so the plain records come out in
    -- exactly the order they always did and a caller that drops `via` records
    -- is left with the list it had before the option existed.
    if opts.include_drive_rush then
        -- The DRC record, by its whole numpad (FrameData.drive_rush_cancel says
        -- why not by key). Its drive_gain is the cost: the source records a
        -- spend as a negative gain, so -(-30000) is 30000, read rather than
        -- written down here. No record, no cost - nil, not a remembered figure.
        local drc_rec = frame_idx and FrameData.drive_rush_cancel(frame_idx) or nil
        local drc_gain = FrameData.drive_gain(drc_rec)
        local drive_cost = drc_gain and -drc_gain or nil
        local drc_record = drc_rec and {
            startup = FrameData.startup(drc_rec),
            recovery = num_or_nil(drc_rec.recovery),
        } or nil

        stats.drc_pairs_considered = 0
        stats.drc_edges = 0
        stats.drc_excluded = 0
        stats.drc_by_confidence = {}
        -- Starters the source gives a drc_on_hit, starters nobody knows about
        -- (no record, or a guessed one), and starters the source lists without
        -- one - the last with their notations, because "3 moves cannot" is
        -- only checkable if it says which three.
        stats.drc_starters_known = 0
        stats.drc_starters_unknown = 0
        stats.drc_not_cancelable = 0
        stats.drc_not_cancelable_moves = {}
        stats.drc_record_found = drc_rec ~= nil

        local function drc_exclude(entry, reason)
            entry.via = M.VIA_DRIVE_RUSH
            entry.reason = reason
            excluded[#excluded + 1] = entry
            stats.by_exclusion[reason] = (stats.by_exclusion[reason] or 0) + 1
            stats.drc_excluded = stats.drc_excluded + 1
        end

        local function consider_drc(a_row, b_row, a_frame, a_info)
            stats.drc_pairs_considered = stats.drc_pairs_considered + 1

            -- B is read on its own, never "after" A. The parent lookup exists
            -- for a derivation spelled as a chain from the move before it, and
            -- after a rush the move before B is the rush.
            local b_frame, b_info = frame_for(b_row)

            -- A rush does not make a throw connect. The opponent is still the
            -- one A hit, and still in hitstun when B comes out.
            local b_is_throw, b_throw_prop, b_record_category = throw_verdict(b_frame)
            if b_is_throw then
                drc_exclude({
                    from = a_row.action_id, to = b_row.action_id,
                    from_notation = a_row.notation, to_notation = b_row.notation,
                    throw_property = b_throw_prop,
                    to_record_category = b_record_category,
                    to_frame_key = b_info and b_info.key,
                    to_frame_join_guessed = FrameData.uncertain(b_info) or nil,
                    evidence = "the frame source marks the second move a throw, and a throw "
                        .. "cannot connect after a hit, with or without a rush in between",
                }, M.EXCLUDED.THROW_AFTER_HIT)
                return
            end

            local a = { reasons = { M.REASON.DRIVE_RUSH_CANCEL }, basis = {}, unknowns = {} }
            local _, b_startup = frames_of_pair(a, a_frame, b_frame, opts)

            local drc_hit = FrameData.drc_on_hit(a_frame)
            a.basis.from_drc_on_hit = drc_hit
            a.basis.from_drc_on_block = FrameData.drc_on_block(a_frame)
            a.basis.drive_cost = drive_cost
            a.basis.drc_record = drc_record

            -- The plain-link knockdown test looks at on_hit. After a rush the
            -- advantage the reasoning rests on is drc_on_hit, so a large one of
            -- those is the same suspicion.
            if drc_hit ~= nil and drc_hit >= (opts.knockdown_suspicion_frames or 18) then
                a.advantage_may_be_knockdown = true
                a.basis.from_drc_on_hit_suspected_knockdown = true
            end

            local a_uncertain = FrameData.uncertain(a_info)
            local b_uncertain = FrameData.uncertain(b_info)
            if a_uncertain or b_uncertain then
                a.frame_join_uncertain = true
                a.basis.from_frame_key = a_info and a_info.key
                a.basis.to_frame_key = b_info and b_info.key
                a.basis.frame_join_guessed = true
            end

            if drc_hit ~= nil and b_startup ~= nil then
                local m = drc_hit - b_startup
                a.basis.drc_margin_frames = m
                if m < (opts.margin_cutoff or 0) then
                    -- Known, and it says no. Excluded with the number, like a
                    -- plain negative margin, under a reason of its own.
                    drc_exclude({
                        from = a_row.action_id, to = b_row.action_id,
                        from_notation = a_row.notation, to_notation = b_row.notation,
                        drc_margin_frames = m,
                        basis = a.basis,
                    }, M.EXCLUDED.DRC_MARGIN_NEGATIVE)
                    return
                end
            else
                a.reasons[#a.reasons + 1] = M.REASON.FRAME_DATA_INCOMPLETE
                if drc_hit == nil then a.unknowns[#a.unknowns + 1] = "from_drc_on_hit" end
                if b_startup == nil then a.unknowns[#a.unknowns + 1] = "to_startup" end
            end

            local edge = Schema.new(Schema.KIND.EDGE, {
                id = drc_edge_id(a_row, b_row),
                via = M.VIA_DRIVE_RUSH,
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
                confidence = drc_confidence_of(a),
                context_dependent = false,
                requires_runtime_validation = {},
                unknown_detail = {},
                provenance = provenance,
            })

            -- The standing three, worded as on a plain edge.
            add_unknown(edge, U.PUSHBACK_RANGE,
                "the frame source records pushback as null; whether the two moves are still "
                .. "in range after the first is only knowable in game")
            add_unknown(edge, U.PUSHBACK_RANGE,
                "a Drive Rush closes distance by an amount no frame table records, so the "
                .. "range B is thrown from is not the range A hit at")
            add_unknown(edge, U.MODERN_SCALING,
                "Modern damage and its simple-input reduction appear in no frame table")
            add_unknown(edge, U.INPUT_TIMING,
                "the actual input window is what the sweep exists to measure")

            -- What makes this edge a rush, all of it unmeasured.
            add_unknown(edge, U.DRIVE_RUSH,
                "how Drive Rush is pressed on this build is unmeasured: the Modern parry "
                .. "button bit has never been witnessed, and 66 needs a measured neutral "
                .. "between its two presses")
            add_unknown(edge, U.DRIVE_RUSH,
                "which action id a Drive Rush Cancel is on this build is disputed - 500, 501 "
                .. "and 504 are each claimed (docs/ComboExplorer/plan-v3-implementation.md) "
                .. "- so a trial cannot yet tell a rush that came out from one that did not")
            add_unknown(edge, U.DRIVE_RUSH,
                "whether the source's drc_on_hit already includes the +4 a normal gains "
                .. "out of a rush is not stated, so drc_margin_frames may be four frames off")
            add_unknown(edge, U.DRIVE_RUSH,
                "whether the combo counter survives the rush between the two hits is unmeasured")
            if drc_rec == nil then
                add_unknown(edge, U.DRIVE_RUSH,
                    "the frame source has no Drive Rush Cancel record, so neither the rush's "
                    .. "drive cost nor its duration is known")
            end

            add_unknown(edge, U.CANCEL_WINDOW,
                "the frame source gives the advantage after a Drive Rush Cancel, not the "
                .. "window in which the first move can be cancelled into the rush")
            for _, u in ipairs(a.unknowns) do
                add_unknown(edge, U.CANCEL_WINDOW,
                    "the frame source is missing " .. u .. " for this pair")
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
            if a_uncertain then
                add_unknown(edge, U.FRAME_DATA_AMBIGUOUS,
                    "for the first move, " .. tostring(FrameData.uncertainty_reason(a_info)))
            end
            if b_uncertain then
                add_unknown(edge, U.FRAME_DATA_AMBIGUOUS,
                    "for the second move, " .. tostring(FrameData.uncertainty_reason(b_info)))
            end
            if a_row.canonical_status ~= "verified" or b_row.canonical_status ~= "verified" then
                add_unknown(edge, U.HITBOX,
                    "which action id this input actually produces is unresolved, so the move "
                    .. "being described may not be the move that comes out")
            end

            candidates[#candidates + 1] = edge
            stats.drc_edges = stats.drc_edges + 1
            stats.drc_by_confidence[edge.confidence] =
                (stats.drc_by_confidence[edge.confidence] or 0) + 1
        end

        for _, a_row in ipairs(from_rows) do
            local a_frame, a_info = frame_for(a_row)
            -- Both fields absent on a record the join is sure of: the source
            -- listed the move and gave it no Drive Rush Cancel. drc_on_block
            -- alone still counts as the source giving it one, with the on-hit
            -- figure unknown.
            local stated_no = a_frame ~= nil and not FrameData.uncertain(a_info)
                and FrameData.drc_on_hit(a_frame) == nil
                and FrameData.drc_on_block(a_frame) == nil
            if stated_no then
                stats.drc_not_cancelable = stats.drc_not_cancelable + 1
                stats.drc_not_cancelable_moves[#stats.drc_not_cancelable_moves + 1] =
                    ("%d:%s %s"):format(a_row.action_id, tostring(a_row.input_method),
                                        tostring(a_row.notation))
            else
                if FrameData.drc_on_hit(a_frame) ~= nil and not FrameData.uncertain(a_info) then
                    stats.drc_starters_known = stats.drc_starters_known + 1
                else
                    stats.drc_starters_unknown = stats.drc_starters_unknown + 1
                end
                for _, b_row in ipairs(to_rows) do
                    consider_drc(a_row, b_row, a_frame, a_info)
                end
                for _, f_row in ipairs(followups) do
                    stats.drc_pairs_considered = stats.drc_pairs_considered + 1
                    drc_exclude({
                        from = a_row.action_id, to = f_row.action_id,
                        from_notation = a_row.notation, to_notation = f_row.notation,
                        -- The value that decided it: the catalog's own mark that B
                        -- is a derivation, which only ever comes straight out of
                        -- its parent. Not a frame number, and not a gap.
                        to_exclusion = f_row.exclusion,
                        evidence = "a target-combo derivation comes out of its parent with "
                            .. "nothing in between, and a Drive Rush is in between",
                    }, M.EXCLUDED.FOLLOWUP_AFTER_DRIVE_RUSH)
                end
            end
        end
    end

    -- The plain counts, like every other un-prefixed stat. With the Drive Rush
    -- pass off these are simply the list lengths, as they always were; with it
    -- on, the lists are longer by drc_edges and drc_excluded, which is where
    -- those are counted.
    stats.candidates = #candidates - (stats.drc_edges or 0)
    stats.excluded = #excluded - (stats.drc_excluded or 0)
    stats.from_moves = #from_rows
    stats.to_moves = #to_rows

    return { candidates = candidates, excluded = excluded, stats = stats }
end

return M
