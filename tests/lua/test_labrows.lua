-- Unit tests for tools/lua/labrows.lua
--
-- The rows this module builds are what the lab database will hold for good, and
-- an evaluation will leave out whatever its flags say. So the things pinned here
-- are the ways a row could quietly say something the trial did not:
--
--   a route recorded as a fake edge imported as a pair
--   a flag set on the wrong rows, or missing from the right ones
--   an unknown written as 0, false or "link"
--   a re-run pointing at a row that is not the one it replaced

local t = require("tests.lua.harness")
dofile("tools/lua/cli.lua")
local L = dofile("tools/lua/labrows.lua")

local F = L.FLAG

local CONDITIONS = {
    schema = "ce.conditions.v1",
    canonical = "positions=controlled:p1=?,p2=?,tol=0.5;resources=unpinned;counter=unknown;screen=unknown;opponent=?",
    context_hash = "fnv1a64:82dd9eebe8f65cc4",
    counter_state = "unknown",
    screen_position = "unknown",
    opponent = { known = false },
    positions = { controlled = true, tolerance = 0.5 },
    resources = { pinned = false, reason = "pin is off" },
}

local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = copy(x) end
    return out
end

-- Written where a test means "this field is absent": a nil in a table
-- constructor is no entry at all, so it could not remove a default.
local NIL = setmetatable({}, { __tostring = function() return "NIL" end })

-- A pair trial as the sweep wrote them before be1c0be: no timing block.
local function pair(over)
    local r = {
        schema = "ce.trial.v1",
        id = "edge 611:manual->1206:manual @ 25 #1",
        edge_id = "611:manual->1206:manual",
        subject_kind = "edge", subject_id = "611:manual->1206:manual",
        delay = 25, delays = { 25 }, attempt = 1,
        verdict = "whiff", answers = "negative", conclusive = true, status = "rejected",
        runtime_verified = true,
        evidence = { verdict = "whiff", a_hit = true },
        provenance = { calibration_id = "CAL-1", game_patch = "24176760" },
        character = "Zangief", control_scheme = "modern",
        conditions = copy(CONDITIONS),
        recorded_at = "2026-09-12T12:16:55Z",
        reason = "B came out and touched nothing",
    }
    for k, v in pairs(over or {}) do
        if v == NIL then r[k] = nil else r[k] = v end
    end
    return r
end

local function flags_of(row)
    local set = {}
    for _, f in ipairs(row and row.quality_flags or {}) do set[f] = true end
    return set
end

-- A lookup that knows one catalog's worth of pairs.
local PAIRS = {
    ["611:manual->1206:manual"] = { status = "candidate", mechanism = "cancel",
                                    a_notation = "弱", b_notation = "236236 + 中" },
    ["601:manual->620:manual"]  = { status = "candidate", mechanism = "link",
                                    a_notation = "弱", b_notation = "2 + 中" },
    ["617:manual->650:manual"]  = { status = "candidate", mechanism = "both",
                                    a_notation = "2 + 弱", b_notation = "中" },
    ["611:manual->678:manual"]  = { status = "candidate", mechanism = "cancel",
                                    a_notation = "弱", b_notation = "22 + 中" },
    ["601:manual->605:manual"]  = { status = "excluded", exclusion = "followup_after_a_move_not_its_parent" },
}
local NOTATION = { ["605:manual"] = "> 中", ["601:manual"] = "弱" }
local ROUTES = {
    ["zangief-assist-ground-truth"] = {
        id = "zangief-assist-ground-truth", schema = "ce.route.v1",
        steps = {
            { action_id = 660, input_method = "simple", notation = "AUTO + 强" },
            { action_id = 655, input_method = "manual", notation = "3 + 中" },
            { action_id = 900, input_method = "simple", notation = "2 + SP" },
        },
    },
}
-- A route whose second step is a derivation of its first, as an operator would write it.
ROUTES["chain"] = {
    id = "chain", schema = "ce.route.v1",
    steps = {
        { action_id = 620, input_method = "manual", notation = "中" },
        { action_id = 605, input_method = "manual", notation = "> 中" },
    },
}
local LOOKUP = {
    pair = function(_, _, key) return PAIRS[key] end,
    notation = function(_, _, id, method) return NOTATION[("%d:%s"):format(id, method)] end,
    route = function(id) return ROUTES[id] end,
}

local function row(rec, fc)
    fc = fc or {}
    if fc.lookup == nil then fc.lookup = LOOKUP end
    fc.source_file = fc.source_file or "reframework/data/ComboExplorer_data/trials/zangief-modern-framedata.jsonl"
    fc.line_no = fc.line_no or 1
    return L.row(rec, fc)
end

-- --- shapes ----------------------------------------------------------------------

t.group("a route's identity is its moves, not their spelling")

do
    local steps = L.pair_steps("601:manual->678:simple")
    t.eq(#steps, 2, "a pair key is two steps")
    t.eq(steps[2].action_id, 678, "with B's id")
    t.eq(steps[2].input_method, "simple", "and B's method")
    t.is_nil(L.pair_steps("zangief-assist-ground-truth@40/2"), "a legacy route id is not a pair")
    t.eq(L.shape_key(steps), "601:manual>678:simple", "the shape is id:method in order")

    local renamed = L.pair_steps("601:manual->678:simple")
    renamed[2].notation = "something else entirely"
    t.eq(L.shape_key(renamed), L.shape_key(steps), "a different notation is the same route")
    t.eq(L.shape_key({ { action_id = 601, input_method = "manual" }, { kind = "drive_rush_cancel" },
                       { action_id = 620, input_method = "manual" } }),
         "601:manual>drive_rush_cancel>620:manual", "a Drive Rush step is spelled by its kind")
    local nokey = L.shape_key({ { notation = "中" } })
    t.is_nil(nokey, "a step with no id has no shape rather than a guessed one")
end

-- --- the legacy route row -----------------------------------------------------------

t.group("a route recorded as an edge is imported as the route (#14)")

do
    local rec = pair({
        id = "edge zangief-assist-ground-truth@40/2 @ 40,2 #1",
        edge_id = "zangief-assist-ground-truth@40/2",
        subject_kind = "edge", subject_id = "zangief-assist-ground-truth@40/2",
        delay = NIL, delays = { 40, 2 }, verdict = "link", answers = "positive", status = "verified",
    })
    local r, why = row(rec, { source_file = "trials/zangief-assist-ground-truth.jsonl" })
    t.ok(r ~= nil, "builds: " .. tostring(why and why[1] and why[1].problem))
    t.eq(r.subject_kind, "route", "the subject is the route")
    t.eq(r.subject_id, "zangief-assist-ground-truth", "named without its gaps")
    t.eq(r.recorded_subject_kind, "edge", "and what the file said is kept beside it")
    t.eq(r.recorded_subject_id, "zangief-assist-ground-truth@40/2", "verbatim")
    t.eq(r.test_kind, "full_combo", "a route run is a full-combo test, not a pair link")
    t.ok(flags_of(r)[F.LEGACY_ROUTE_SUBJECT], "and the reconstruction is flagged")
    t.eq(r.route.shape_key, "660:simple>655:manual>900:simple", "the route's shape comes from its definition")
    t.eq(r.route.steps[1].notation, "AUTO + 强", "with the operator's notation")
    t.eq_list(r.derived.legacy_gaps, { 40, 2 }, "the gaps read out of the id are kept")
    t.ok(not flags_of(r)[F.MOTION_BUTTON_LATE], "the pair timing rules do not apply to a route")
    t.ok(not flags_of(r)[F.UNPLAYABLE_INPUT], "an operator's route vouches for its own order")

    local chain = row(pair({ edge_id = "chain@4", subject_id = "chain@4", delays = { 4 }, delay = 4,
                             id = "edge chain@4 @ 4 #1" }))
    t.ok(not flags_of(chain)[F.UNPLAYABLE_INPUT],
         "a follow-up the operator placed after its parent is playable: the route vouches for the order")

    local unknown = row(pair({ edge_id = "some-route@4", subject_id = "some-route@4", delays = { 4 }, delay = 4,
                               id = "edge some-route@4 @ 4 #1" }))
    t.eq(unknown.subject_kind, "route", "a legacy route with no definition is still a route")
    t.is_nil(unknown.route, "but it has no shape, rather than an invented one")

    local modern = row(pair({ edge_id = NIL, subject_kind = "route", subject_id = "zangief-assist-ground-truth",
                              route_id = "zangief-assist-ground-truth", delay = NIL, delays = { 40, 2 },
                              id = "route zangief-assist-ground-truth @ 40,2 #1" }))
    t.eq(modern.subject_kind, "route", "a route row written after #14 is a route")
    t.ok(not flags_of(modern)[F.LEGACY_ROUTE_SUBJECT], "and is not flagged as legacy")

    local p = row(pair())
    t.eq(p.subject_kind, "edge", "a real pair stays a pair")
    t.eq(p.test_kind, "pair_link", "and is a pair-link test")
    t.ok(not flags_of(p)[F.LEGACY_ROUTE_SUBJECT], "and is not flagged legacy")
end

-- --- evidence_missing ------------------------------------------------------------------

t.group("evidence_missing is an unanswered row with nothing observed")

do
    local wm = row(pair({ verdict = "wrong_move", answers = "unanswered", conclusive = false,
                          status = "runtime_pending", evidence = NIL }))
    t.ok(flags_of(wm)[F.EVIDENCE_MISSING], "a wrong_move with no evidence is flagged")
    t.ok(wm.derived.flag_reasons[F.EVIDENCE_MISSING]:find("b5f67bc") ~= nil,
         "and a row from before b5f67bc says so")

    local kept = row(pair({ verdict = "wrong_move", answers = "unanswered", conclusive = false,
                            status = "runtime_pending", evidence = { actions_seen = {} } }))
    t.ok(not flags_of(kept)[F.EVIDENCE_MISSING], "an unanswered row that kept its evidence is not")

    local answered = row(pair({ evidence = NIL }))
    t.ok(not flags_of(answered)[F.EVIDENCE_MISSING],
         "an answered row is not this flag - that loss happened only to unanswered rows")
    t.eq(answered.has_evidence, false, "though the row still says it has none")
end

-- --- the timing rules -------------------------------------------------------------------

t.group("link_timing_on_cancel_pair and motion_button_late (be1c0be)")

do
    local r = row(pair())
    local fl = flags_of(r)
    t.ok(fl[F.LINK_TIMING_ON_CANCEL_PAIR], "a cancel-only pair with no timing block was pressed at the link gap")
    t.ok(fl[F.MOTION_BUTTON_LATE], "and 236236's button came late")
    t.eq(r.derived.b_motion_ticks, 5, "by five ticks")
    t.eq(r.derived.mechanism, "cancel", "the mechanism is recorded")

    local timed = row(pair({ timing = { mechanism = "cancel", prediction = "cancel", b_motion_ticks = 5 } }))
    t.ok(not flags_of(timed)[F.LINK_TIMING_ON_CANCEL_PAIR], "a row with a timing block was timed for its mechanism")
    t.ok(not flags_of(timed)[F.MOTION_BUTTON_LATE], "and had its motion taken off the gap")
    t.eq(timed.has_timing, true, "and says it has timing")

    local both = row(pair({ edge_id = "617:manual->650:manual", subject_id = "617:manual->650:manual",
                            id = "edge 617:manual->650:manual @ 25 #1" }))
    t.ok(not flags_of(both)[F.LINK_TIMING_ON_CANCEL_PAIR], "a pair that can link as well was fairly pressed at the link gap")
    t.ok(not flags_of(both)[F.MOTION_BUTTON_LATE], "and a B with no direction is not late")

    local link = row(pair({ edge_id = "601:manual->620:manual", subject_id = "601:manual->620:manual",
                            id = "edge 601:manual->620:manual @ 25 #1" }))
    t.ok(not flags_of(link)[F.MOTION_BUTTON_LATE], "one direction is not a motion: 2 + 中 is one mask")
    t.eq(link.derived.b_motion_ticks, 0, "and counts as zero ticks, which is measured, not unknown")

    local d4 = row(pair({ delay = 4, delays = { 4 }, id = "edge 611:manual->1206:manual @ 4 #1" }),
                   { source_file = "reframework/data/ComboExplorer_data/trials/zangief-modern-delay4.jsonl" })
    local d4f = flags_of(d4)
    t.ok(d4f[F.FIXED_DELAY_4], "the delay-4 file is flagged by name")
    t.ok(not d4f[F.LINK_TIMING_ON_CANCEL_PAIR], "and its gap 4 was inside the hitstop, which is not link timing")
    t.ok(d4f[F.MOTION_BUTTON_LATE], "but its motions were still counted before the button")

    local elsewhere = row(pair(), { source_file = "trials/zangief-modern-framedata.jsonl" })
    t.ok(not flags_of(elsewhere)[F.FIXED_DELAY_4], "no other file is")

    local nolookup = row(pair(), { lookup = {} })
    local nf = flags_of(nolookup)
    t.ok(not nf[F.LINK_TIMING_ON_CANCEL_PAIR], "a pair nothing knows about is not called a cancel")
    t.ok(not nf[F.MOTION_BUTTON_LATE], "nor late")
    t.is_nil(nolookup.derived.mechanism, "its mechanism is unknown, not link")
    t.eq(nolookup.derived.candidate, "unknown", "and the row says nothing could tell")
    t.is_nil(nolookup.derived.b_motion_ticks, "an unread notation has no motion count")
end

-- --- superseded_rerun ---------------------------------------------------------------------

t.group("superseded_rerun is decided per row: same key, same cohort")

do
    local old = pair()
    local new = pair({ recorded_at = "2026-09-12T13:00:00Z", verdict = "combo_broke" })
    local other_cal = pair({ provenance = { calibration_id = "CAL-2", game_patch = "24176760" },
                             delays = { 30 }, delay = 30, id = "edge 611:manual->1206:manual @ 30 #1" })
    local successor = L.index_reruns({ { line_no = 7, record = new } })

    local r = row(old, { source_file = "trials/zangief-modern-framedata-singleid.jsonl", successor = successor })
    t.ok(flags_of(r)[F.SUPERSEDED_RERUN], "a row the re-run repeats is superseded")
    t.ok(r.derived.flag_reasons[F.SUPERSEDED_RERUN]:find("line 7") ~= nil, "and says where the re-run is")

    local cohort = pair({ provenance = { calibration_id = "CAL-2", game_patch = "24176760" } })
    local c = row(cohort, { source_file = "trials/zangief-modern-framedata-singleid.jsonl", successor = successor })
    t.ok(not flags_of(c)[F.SUPERSEDED_RERUN], "the same key under another calibration is a different experiment")

    local gap = row(other_cal, { source_file = "trials/zangief-modern-framedata-singleid.jsonl", successor = successor })
    t.ok(not flags_of(gap)[F.SUPERSEDED_RERUN], "a key the re-run did not repeat is not superseded")

    local g = row(old, { source_file = "trials/zangief-assist-ground-truth-gap2to28.jsonl", successor = successor })
    t.ok(not flags_of(g)[F.SUPERSEDED_RERUN], "a file with no successor rule is never flagged, whatever it is handed")

    local pred = { source_file = "trials/zangief-modern-framedata-singleid.jsonl",
                   index = L.index_reruns({ { line_no = 3, record = old } }) }
    local n = row(new, { source_file = "trials/zangief-modern-framedata.jsonl", predecessor = pred })
    t.eq(n.supersedes and n.supersedes.line_no, 3, "the re-run points at the row it replaces")
    t.eq(n.supersedes and n.supersedes.source_file, pred.source_file, "in the predecessor file")
    t.ok(not flags_of(n)[F.SUPERSEDED_RERUN], "and is not itself superseded")

    local twice = { source_file = pred.source_file,
                    index = L.index_reruns({ { line_no = 3, record = old }, { line_no = 9, record = old } }) }
    local amb = row(new, { source_file = "trials/zangief-modern-framedata.jsonl", predecessor = twice })
    t.is_nil(amb.supersedes, "a key the predecessor holds twice points at neither")
end

-- --- unplayable_input ---------------------------------------------------------------------

t.group("unplayable_input is what SequenceCompiler.unplayable would set aside (#49)")

do
    local rep = row(pair({ edge_id = "611:manual->678:manual", subject_id = "611:manual->678:manual",
                           id = "edge 611:manual->678:manual @ 25 #1" }))
    t.ok(flags_of(rep)[F.UNPLAYABLE_INPUT], "22 + 中 plays as one held 2")
    t.eq_list(rep.derived.unplayable, { "repeat" }, "and the kind is named")

    local fu = row(pair({ edge_id = "601:manual->605:manual", subject_id = "601:manual->605:manual",
                          id = "edge 601:manual->605:manual @ 25 #1" }))
    t.ok(flags_of(fu)[F.UNPLAYABLE_INPUT], "a follow-up after a move nothing says it follows")
    t.eq_list(fu.derived.unplayable, { "followup_context" }, "is a context problem")
    t.eq(fu.route.steps[2].notation, "> 中", "an excluded pair's notation comes from the catalog by method")
    t.eq(fu.derived.candidate, "excluded", "and the row says the generator excludes it")
    t.eq(fu.derived.exclusion, "followup_after_a_move_not_its_parent", "and why")

    PAIRS["601:manual->605:manual"] = { status = "candidate", mechanism = "cancel", context_known = true,
                                        a_notation = "弱", b_notation = "> 中" }
    local vouched = row(pair({ edge_id = "601:manual->605:manual", subject_id = "601:manual->605:manual",
                               id = "edge 601:manual->605:manual @ 25 #1" }))
    t.ok(not flags_of(vouched)[F.UNPLAYABLE_INPUT], "a follow-up the generator vouches for is playable")
    PAIRS["601:manual->605:manual"] = { status = "excluded", exclusion = "followup_after_a_move_not_its_parent" }

    local fine = row(pair())
    t.ok(not flags_of(fine)[F.UNPLAYABLE_INPUT], "236236 + 中 plays")
    t.is_nil(fine.derived.unplayable, "and no kind is recorded")

    local blind = row(pair({ edge_id = "999:manual->998:manual", subject_id = "999:manual->998:manual",
                             id = "edge 999:manual->998:manual @ 25 #1" }))
    t.ok(not flags_of(blind)[F.UNPLAYABLE_INPUT], "a step with no notation is not judged unplayable")
    t.is_nil(blind.route.steps[1].notation, "and its notation stays unknown")
end

-- --- unknowns ---------------------------------------------------------------------------------

t.group("unknown stays nil")

do
    local r = row(pair({ conditions = NIL, runtime_verified = NIL, evidence = { a_hit = true } }))
    t.is_nil(r.context, "no conditions recorded is no context, not an uncontrolled one")
    t.is_nil(r.measured_damage, "no damage block is no damage, not zero")
    t.is_nil(r.runtime_verified, "an absent runtime_verified is not false")
    t.is_nil(r.started_at_frame, "nor is a missing frame zero")

    local unread = row(pair({ evidence = { damage = { hp_delta = 120 } } }))
    t.is_nil(unread.measured_damage, "a damage field that never resolved is still unknown")

    local zero = row(pair({ evidence = { damage = { combo_damage = 0 } } }))
    t.eq(zero.measured_damage, 0, "a measured zero is a value and is kept")

    local measured = row(pair({ evidence = { damage = { combo_damage = 1840 } } }))
    t.eq(measured.measured_damage, 1840, "and a reading is the reading")

    local c = row(pair())
    t.eq(c.context.positions_controlled, true, "positions controlled is kept as recorded")
    t.eq(c.context.resources_pinned, false, "and unpinned is false, a fact, not nil")
    t.eq(c.context.counter_state, "unknown", "counter state unknown stays unknown")
    t.is_nil(c.context.opponent_character, "an unrecorded opponent is nil, not '?'")
    t.eq(c.context.context_hash, CONDITIONS.context_hash, "the hash is recomputed from the canonical string")

    local clean = row(pair({ edge_id = "617:manual->650:manual", subject_id = "617:manual->650:manual",
                             id = "edge 617:manual->650:manual @ 25 #1" }))
    t.eq(#clean.quality_flags, 0, "a row no rule touches has an empty flag list")
    t.is_nil(clean.derived.flag_reasons, "and no reasons")
end

-- --- refusals ---------------------------------------------------------------------------------

t.group("a line that cannot be believed is refused, not repaired")

do
    local r, why = row(pair({ verdict = "teleported" }))
    t.is_nil(r, "an unknown verdict is refused")
    t.eq(why and why[1].field, "verdict", "and says which field")

    local a, awhy = row(pair({ answers = "positive" }))
    t.is_nil(a, "answers that disagree with the verdict are refused")
    t.eq(awhy and awhy[1].field, "answers", "by name")

    local bad = copy(CONDITIONS)
    bad.canonical = "positions=uncontrolled;resources=unpinned;counter=unknown;screen=unknown;opponent=?"
    local c, cwhy = row(pair({ conditions = bad }))
    t.is_nil(c, "a canonical string that does not describe its own fields is refused")
    t.eq(cwhy and cwhy[1].field, "conditions", "as a conditions problem")

    local s, swhy = row(pair({ edge_id = NIL, subject_kind = NIL, subject_id = NIL }))
    t.is_nil(s, "a row with no subject is refused")
    t.eq(swhy and swhy[1].field, "subject", "as a subject problem")
end

-- --- pair_index --------------------------------------------------------------------------------

t.group("pair_index: every pair is a candidate, an exclusion, or not known")

do
    local edges = {
        { from = { action_id = 611, input_method = "manual", notation = "弱" },
          to = { action_id = 1206, input_method = "manual", notation = "236236 + 中" },
          reasons = { "super_cancel" } },
    }
    local excluded = { { from = 601, to = 605, reason = "followup_after_a_move_not_its_parent",
                         from_notation = "弱", to_notation = "> 中" } }
    local key_of = function(e)
        return ("%d:%s->%d:%s"):format(e.from.action_id, e.from.input_method, e.to.action_id, e.to.input_method)
    end
    local find = L.pair_index(edges, excluded, key_of)
    local c = find("611:manual->1206:manual")
    t.eq(c and c.status, "candidate", "a generated edge is a candidate")
    t.eq(c and c.mechanism, "cancel", "with CandidateGenerator's mechanism")
    local x = find("601:manual->605:simple")
    t.eq(x and x.status, "excluded", "an exclusion is found for any method pair of its ids")
    t.is_nil(x and x.b_notation, "without a notation, since the exclusion does not say which method it spelled")
    t.is_nil(find("1:manual->2:manual"), "and anything else is not known")
end

-- --- the committed logs --------------------------------------------------------------------------

t.group("the committed framedata log, through the real generator")

do
    local P = dofile("tools/lua/pipeline.lua")
    local json = dofile("tools/lua/json.lua")
    local ctx = P.load({})
    if not ctx then
        t.fail("the Zangief catalog did not load")
    else
        local gen = P.generate(ctx, {})
        local find = L.pair_index(ctx.plain_edges, gen.excluded, P.edge_pair_key)
        local notation = {}
        for _, r in ipairs(ctx.cat.rows) do notation[("%d:%s"):format(r.action_id, r.input_method)] = r.notation end
        local lookup = {
            pair = function(_, _, key) return find(key) end,
            notation = function(_, _, id, m) return notation[("%d:%s"):format(id, m)] end,
            route = function() return nil end,
        }
        local path = "reframework/data/ComboExplorer_data/trials/zangief-modern-framedata.jsonl"
        local counts, n, refused = {}, 0, 0
        local i = 0
        for line in io.lines(path) do
            i = i + 1
            local r = L.row(json.decode(line), { source_file = path, line_no = i, lookup = lookup })
            if r then
                n = n + 1
                for _, f in ipairs(r.quality_flags) do counts[f] = (counts[f] or 0) + 1 end
            else
                refused = refused + 1
            end
        end
        t.eq(n, 216, "every one of the 216 lines becomes a row")
        t.eq(refused, 0, "and none is refused")
        -- be1c0be's count: the pairs whose only mechanism is a cancel, measured
        -- only at the link gap.
        t.eq(counts[F.LINK_TIMING_ON_CANCEL_PAIR], 73, "73 rows are cancel pairs pressed at link timing")
        t.eq(counts[F.EVIDENCE_MISSING], 98, "the 98 wrong_moves are the rows without evidence")
        t.is_nil(counts[F.LEGACY_ROUTE_SUBJECT], "a pair sweep has no legacy route rows")
    end
end

return t.finish()
