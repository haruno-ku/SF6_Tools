-- Unit tests for tools/lua/labeval.lua
--
-- An evaluation is what the lab database will say a combo IS, so the things
-- pinned here are the ways it could say more than the runs do:
--
--   a run left out that should count, or counted that should be left out
--   a flawed negative turning a link into "mixed"
--   two cohorts folded into one statement
--   an evidence set whose hash depends on the order the runs arrived in
--   a route called reproduced on one link, or a pair on links at two delays

local t = require("tests.lua.harness")
dofile("tools/lua/cli.lua")
local E  = dofile("tools/lua/labeval.lua")
local L  = dofile("tools/lua/labrows.lua")
local SR = dofile("tools/lua/sweepreport.lua")
local ResultCollector = require("func/ComboExplorer/core/ResultCollector")
local TestContext     = require("func/ComboExplorer/core/TestContext")

local F, R, INC = L.FLAG, E.RESULT, E.INCLUSION

local CANON = "positions=controlled:p1=?,p2=?,tol=0.5;resources=unpinned;counter=unknown;screen=unknown;opponent=?"
local EDGE = "617:manual->1206:manual"

local ANSWER = { link = "positive", whiff = "negative", blocked = "negative", combo_broke = "negative",
                 wrong_move = "unanswered", a_failed = "unanswered", inconclusive = "unanswered" }

local seq = 0
-- A lab run as the importer hands it over: a labrows row plus event_key and sources.
local function run(verdict, delay, over)
    seq = seq + 1
    local r = {
        kind = "run",
        event_key = ("sha256:%064d"):format(seq),
        schema = "ce.trial.v1",
        character = "Zangief", control_scheme = "modern",
        game_patch = "24176760", calibration_id = "CAL-B",
        context = { canonical = CANON },
        subject_kind = "edge", subject_id = EDGE, test_kind = "pair_link",
        route = { shape_key = "617:manual>1206:manual", steps = {
            { step_no = 1, kind = "move", action_id = 617, input_method = "manual", notation = "2 + 弱" },
            { step_no = 2, kind = "move", action_id = 1206, input_method = "manual", notation = "236236 + 中" },
        } },
        attempt = 1, delays = type(delay) == "table" and delay or { delay },
        verdict = verdict, answers = ANSWER[verdict],
        recorded_at = "2026-09-12T10:00:00Z",
        quality_flags = {},
        sources = {},
    }
    for k, v in pairs(over or {}) do r[k] = v end
    return r
end

local function route_run(verdict, gaps, over)
    local o = {
        subject_kind = "route", subject_id = "zangief-assist-ground-truth", test_kind = "full_combo",
        route = { shape_key = "660:simple>655:manual>900:simple", steps = {
            { step_no = 1, kind = "move", action_id = 660, input_method = "simple", notation = "AUTO + 强" },
            { step_no = 2, kind = "move", action_id = 655, input_method = "manual", notation = "3 + 中" },
            { step_no = 3, kind = "move", action_id = 900, input_method = "simple", notation = "2 + SP" },
        } },
    }
    for k, v in pairs(over or {}) do o[k] = v end
    return run(verdict, gaps, o)
end

local POLICY = E.policy()

local function only(evs)
    t.eq(#evs, 1, "one evaluation")
    return evs[1] or { measured_summary = { excluded_by_reason = {} }, runs = {} }
end

local function evaluate(runs)
    local evs, problems = E.evaluate(runs)
    t.eq(#(problems or {}), 0, "no problems: " .. table.concat(problems or {}, "; "))
    return evs or {}
end

-- --- the policy ---------------------------------------------------------------------

t.group("the policy names every flag labrows can set, once")

do
    t.ok(POLICY ~= nil, "ce-eval-v1 loads and checks")
    t.eq(POLICY.key, "ce-eval-v1", "under its key")
    local named = {}
    for _, list in ipairs({ POLICY.rules.exclude_run, POLICY.rules.exclude_negative, POLICY.rules.never_exclude }) do
        for _, f in ipairs(list) do named[f] = (named[f] or 0) + 1 end
    end
    for _, f in pairs(F) do t.eq(named[f], 1, "flag " .. f .. " is classified exactly once") end
    t.eq(POLICY.rules.route.confirm_links, SR.CONFIRM_LINKS, "the route rule's number is the one SweepReport applies")
    t.eq(POLICY.rules.labrows_version, L.VERSION, "and it records which flag rules it was written against")

    local function variant(mut)
        local p = { key = "x", version = 1, rules = {} }
        for k, v in pairs(POLICY.rules) do p.rules[k] = v end
        mut(p.rules)
        return E.check_policy(p)
    end
    local ok, why = variant(function(r) r.never_exclude = { F.LEGACY_ROUTE_SUBJECT } end)
    t.eq(ok, false, "a policy that forgets a flag is refused")
    t.ok(table.concat(why, " "):find("evidence_missing", 1, true), "and says which flag")
    ok = variant(function(r) r.never_exclude = { F.LEGACY_ROUTE_SUBJECT, F.EVIDENCE_MISSING, F.FIXED_DELAY_4 } end)
    t.eq(ok, false, "a flag named twice is refused")
    ok = variant(function(r) r.route = { confirm_links = 3 } end)
    t.eq(ok, false, "a route rule that is not SweepReport's is refused")
    ok = variant(function(r) r.never_exclude = { F.LEGACY_ROUTE_SUBJECT, F.EVIDENCE_MISSING, "made_up" } end)
    t.eq(ok, false, "a flag labrows does not set is refused")
    t.is_nil((E.policy("ce-eval-v0")), "an unknown policy key gives no policy")
end

-- --- rule 1: superseded ---------------------------------------------------------------

t.group("rule 1: a superseded re-run is left out, whatever it answered")

for _, v in ipairs({ "link", "whiff", "wrong_move" }) do
    local inc, why = E.include(run(v, 4, { quality_flags = { F.SUPERSEDED_RERUN } }), POLICY)
    t.eq(inc, INC.EXCLUDED, v .. " superseded: excluded")
    t.eq(why, F.SUPERSEDED_RERUN, "  with superseded_rerun as the reason")
end

do
    local inc, why = E.include(run("whiff", 4, { quality_flags = { F.FIXED_DELAY_4, F.SUPERSEDED_RERUN } }), POLICY)
    t.eq(why, F.SUPERSEDED_RERUN, "superseded outranks a negative's flag as the reason")
end

-- --- rule 2: a link is a link -----------------------------------------------------------

t.group("rule 2: a positive counts under every flawed-timing flag")

for _, f in ipairs({ F.FIXED_DELAY_4, F.UNPLAYABLE_INPUT, F.LINK_TIMING_ON_CANCEL_PAIR,
                     F.MOTION_BUTTON_LATE, F.LEGACY_ROUTE_SUBJECT }) do
    local inc, why = E.include(run("link", 4, { quality_flags = { f } }), POLICY)
    t.eq(inc, INC.COUNTED, "link with " .. f .. ": counted")
    t.is_nil(why, "  and no reason")
end

-- --- rule 3: a negative has to have asked the question ------------------------------------

t.group("rule 3: a negative counts only when the run asked at the right timing with a pressable input")

for _, f in ipairs({ F.FIXED_DELAY_4, F.UNPLAYABLE_INPUT, F.LINK_TIMING_ON_CANCEL_PAIR, F.MOTION_BUTTON_LATE }) do
    for _, v in ipairs({ "whiff", "blocked", "combo_broke" }) do
        local inc, why = E.include(run(v, 4, { quality_flags = { f } }), POLICY)
        t.eq(inc, INC.EXCLUDED, v .. " with " .. f .. ": excluded")
        t.eq(why, f, "  because " .. f)
    end
end

do
    local inc = E.include(run("whiff", 4), POLICY)
    t.eq(inc, INC.COUNTED, "an unflagged whiff is a conclusive failure")
    inc = E.include(run("whiff", 4, { quality_flags = { F.LEGACY_ROUTE_SUBJECT, F.EVIDENCE_MISSING } }), POLICY)
    t.eq(inc, INC.COUNTED, "legacy_route_subject and evidence_missing never exclude a negative")

    local _, why = E.include(run("whiff", 4, { quality_flags = { F.MOTION_BUTTON_LATE, F.FIXED_DELAY_4 } }), POLICY)
    t.eq(why, F.FIXED_DELAY_4, "several flags: the first in the policy's order is the reason")
    _, why = E.include(run("whiff", 4, { quality_flags = { F.MOTION_BUTTON_LATE, F.LINK_TIMING_ON_CANCEL_PAIR } }), POLICY)
    t.eq(why, F.LINK_TIMING_ON_CANCEL_PAIR, "  (link timing before a late button)")

    -- A flag one file knows about is true of the observation wherever it sits.
    local r = run("whiff", 4, { sources = {
        { source_file = "a.jsonl", line_no = 1, quality_flags = {} },
        { source_file = "zangief-modern-delay4.jsonl", line_no = 9, quality_flags = { F.FIXED_DELAY_4 } },
    } })
    inc, why = E.include(r, POLICY)
    t.eq(inc, INC.EXCLUDED, "a flag carried only by one run_sources location still excludes")
    t.eq(why, F.FIXED_DELAY_4, "  with that flag")
    t.eq(table.concat(E.flags_of(r), ","), F.FIXED_DELAY_4, "flags_of is the union, as lab.run_quality")
end

-- --- rule 4: unanswered ----------------------------------------------------------------

t.group("rule 4: unanswered stays unanswered")

for _, f in ipairs({ F.FIXED_DELAY_4, F.UNPLAYABLE_INPUT, F.LINK_TIMING_ON_CANCEL_PAIR,
                     F.MOTION_BUTTON_LATE, F.EVIDENCE_MISSING, F.LEGACY_ROUTE_SUBJECT }) do
    local inc = E.include(run("wrong_move", 4, { quality_flags = { f } }), POLICY)
    t.eq(inc, INC.COUNTED, "wrong_move with " .. f .. ": counted as unanswered")
end

do
    local inc, why = E.include(run("link", 4, { quality_flags = { "brand_new_flag" } }), POLICY)
    t.is_nil(inc, "a flag the policy does not classify is refused, not passed")
    t.ok(tostring(why):find("brand_new_flag", 1, true), "  and named")
end

-- --- result mapping ----------------------------------------------------------------------

t.group("result mapping")

t.eq(E.result({ successes = 0, failures = 0 }), R.PENDING, "nothing answered: pending")
t.eq(E.result({ successes = 0, failures = 0, reproduced = true }), R.PENDING, "  even if something claims reproduced")
t.eq(E.result({ successes = 1, failures = 0 }), R.OBSERVED_SUCCESS, "a link, no failure: observed_success")
t.eq(E.result({ successes = 2, failures = 0, reproduced = true }), R.REPRODUCED, "reproduced")
t.eq(E.result({ successes = 2, failures = 3, reproduced = true }), R.REPRODUCED, "reproduced outranks failures (the window)")
t.eq(E.result({ successes = 1, failures = 1 }), R.MIXED, "links and failures, not reproduced: mixed")
t.eq(E.result({ successes = 0, failures = 2 }), R.NO_SUCCESS_OBSERVED, "failures only: no_success_observed")

-- --- pairs: ConfirmedEdge decides --------------------------------------------------------

t.group("pairs fold through ConfirmedEdge")

do
    local ev = only(evaluate({ run("link", 4), run("link", 4, { attempt = 2 }) }))
    t.eq(ev.result, R.REPRODUCED, "two links at one delay: reproduced")
    t.eq(ev.measured_summary.stable, true, "  ConfirmedEdge called it stable")
    t.eq(ev.measured_summary.rule, "confirmed_edge", "  by the pair rule")
    t.eq(ev.successful_runs, 2, "  2 successes")
    t.eq(ev.combo.moves_key, "617>1206", "the combo is shown by its moves")
    t.eq(ev.combo.notation_chain, "2 + 弱 > 236236 + 中", "  and its notations")

    ev = only(evaluate({ run("link", 4), run("link", 22) }))
    t.eq(ev.result, R.OBSERVED_SUCCESS, "links at two delays, once each: observed_success, not reproduced")
    t.eq(table.concat(ev.measured_summary.linked_gaps, ","), "4,22", "  linked gaps sorted by number")

    ev = only(evaluate({ run("link", 4), run("link", 4, { attempt = 2 }), run("whiff", 8) }))
    t.eq(ev.result, R.REPRODUCED, "stable at 4 with a whiff at 8: reproduced (the window)")
    t.eq(ev.conclusive_failures, 1, "  the failure is still counted")
    t.eq(ev.measured_summary.window.from, 4, "  window from ConfirmedEdge")

    ev = only(evaluate({ run("link", 4), run("whiff", 8) }))
    t.eq(ev.result, R.MIXED, "one link, one counted whiff: mixed")

    ev = only(evaluate({ run("link", 4), run("whiff", 8, { quality_flags = { F.MOTION_BUTTON_LATE } }) }))
    t.eq(ev.result, R.OBSERVED_SUCCESS, "a whiff pressed late does not make a link mixed")
    t.eq(ev.excluded_runs, 1, "  it is excluded")
    t.eq(ev.measured_summary.excluded_by_reason[F.MOTION_BUTTON_LATE], 1, "  counted under its reason")

    ev = only(evaluate({ run("whiff", 4), run("blocked", 6) }))
    t.eq(ev.result, R.NO_SUCCESS_OBSERVED, "counted whiffs only: no_success_observed")

    ev = only(evaluate({ run("wrong_move", 4), run("a_failed", 6, { quality_flags = { F.EVIDENCE_MISSING } }) }))
    t.eq(ev.result, R.PENDING, "unanswered only: pending")
    t.eq(ev.unanswered_runs, 2, "  both counted as unanswered")

    ev = only(evaluate({ run("link", 4, { quality_flags = { F.SUPERSEDED_RERUN } }),
                         run("whiff", 4, { quality_flags = { F.FIXED_DELAY_4 } }) }))
    t.eq(ev.result, R.PENDING, "every run excluded: pending")
    t.eq(ev.excluded_runs, 2, "  both kept as excluded")
    t.eq(#ev.runs, 2, "  and listed in the evaluation's runs")
    t.eq(ev.measured_summary.stable, false, "  nothing stable")

    ev = only(evaluate({ run("link", 4, { quality_flags = { F.SUPERSEDED_RERUN } }), run("link", 4, { attempt = 2 }) }))
    t.eq(ev.result, R.OBSERVED_SUCCESS, "a superseded link does not make a pair reproduced")
end

-- --- cohorts --------------------------------------------------------------------------------

t.group("cohorts are evaluated separately")

do
    local evs = evaluate({
        run("link", 4), run("link", 4, { attempt = 2, calibration_id = "CAL-A" }),
        run("whiff", 4, { calibration_id = "CAL-A", attempt = 3 }),
    })
    t.eq(#evs, 2, "two calibrations: two evaluations")
    local by_cal = {}
    for _, ev in ipairs(evs) do by_cal[ev.cohort_key:match("cal=([^;]+)")] = ev end
    t.eq(by_cal["CAL-B"] and by_cal["CAL-B"].result, R.OBSERVED_SUCCESS, "CAL-B alone: one link")
    t.eq(by_cal["CAL-A"] and by_cal["CAL-A"].result, R.MIXED, "CAL-A alone: a link and a whiff")

    evs = evaluate({ run("link", 4), run("link", 4, { attempt = 2, context = { canonical = CANON .. "x" } }) })
    t.eq(#evs, 2, "different conditions: two evaluations, neither reproduced")
    evs = evaluate({ run("link", 4), run("link", 4, { attempt = 2, game_patch = "other" }) })
    t.eq(#evs, 2, "different patch: two evaluations")
    local unrecorded = run("link", 4, { attempt = 2 })
    unrecorded.context = nil   -- a nil in the constructor would not remove the default
    evs = evaluate({ run("link", 4), unrecorded })
    t.eq(#evs, 2, "unrecorded conditions are their own cohort, not merged with recorded ones")

    -- The key from the row is the key the record gives.
    local record = {
        schema = "ce.trial.v1", edge_id = EDGE, subject_kind = "edge", subject_id = EDGE,
        delay = 4, attempt = 1, verdict = "link",
        character = "Zangief", control_scheme = "modern",
        provenance = { calibration_id = "CAL-B", game_patch = "24176760" },
        conditions = { schema = "ce.conditions.v1", counter_state = "unknown", screen_position = "unknown",
                       opponent = { known = false }, positions = { controlled = true, tolerance = 0.5 },
                       resources = { pinned = false } },
    }
    t.eq(TestContext.canonical(record.conditions), CANON, "(fixture: the fields spell CANON)")
    t.eq(E.cohort_key(run("link", 4)), ResultCollector.cohort_key(record),
         "cohort_key from the row equals ResultCollector.cohort_key of the record")
    local bare = run("link", 4); bare.context = nil
    local rec2 = {}; for k, v in pairs(record) do rec2[k] = v end; rec2.conditions = nil
    t.eq(E.cohort_key(bare), ResultCollector.cohort_key(rec2), "  and with no conditions recorded")
end

-- --- the evidence set -------------------------------------------------------------------------

t.group("evidence_set: stable, order-independent, and sensitive to what counted")

do
    local a = run("link", 4)
    local b = run("whiff", 8, { quality_flags = { F.FIXED_DELAY_4 } })
    local c = run("wrong_move", 6)
    local one = only(evaluate({ a, b, c }))
    local two = only(evaluate({ c, a, b }))
    t.eq(one.evidence_set, two.evidence_set, "the same runs in another order give the same text")
    t.eq(only(evaluate({ b, c, a })).evidence_set, one.evidence_set, "  and a third order")
    t.ok(one.evidence_set:find("^policy=ce%-eval%-v1;version=1\n"), "it starts with the policy key and version")
    t.ok(one.evidence_set:find(b.event_key .. "\texcluded\tfixed_delay_4", 1, true), "an excluded run's line carries its reason")
    t.ok(one.evidence_set:find(a.event_key .. "\tcounted\t", 1, true), "a counted run's line has an empty reason")

    local text = E.evidence_set(POLICY, { { event_key = "k2", inclusion = "counted" }, { event_key = "k1", inclusion = "excluded", exclusion_reason = "fixed_delay_4" } })
    t.eq(text, "policy=ce-eval-v1;version=1\nk1\texcluded\tfixed_delay_4\nk2\tcounted\t", "the exact text")

    local b2 = {}; for k, v in pairs(b) do b2[k] = v end
    b2.quality_flags = {}
    t.ok(only(evaluate({ a, b2, c })).evidence_set ~= one.evidence_set, "a run changing from excluded to counted changes the text")
    t.ok(only(evaluate({ a, c })).evidence_set ~= one.evidence_set, "one run fewer changes the text")
    local other = { key = "ce-eval-v2", version = 2 }
    t.ok(E.evidence_set(other, one.runs) ~= one.evidence_set, "another policy over the same runs changes the text")
    t.eq(one.runs[1].event_key < one.runs[2].event_key and one.runs[2].event_key < one.runs[3].event_key, true,
         "the evaluation's runs are listed sorted by event_key")
end

-- --- routes: the combo rule ------------------------------------------------------------------------

t.group("routes use SweepReport's combo rule")

do
    t.is_nil(SR.combo_status(0), "combo_status: no link, not a combo")
    t.eq(SR.combo_status(1), SR.COMBO.ONCE, "combo_status: one link, once")
    t.eq(SR.combo_status(2), SR.COMBO.CONFIRMED, "combo_status: two, confirmed")

    local ev = only(evaluate({ route_run("link", { 40, 2 }), route_run("link", { 44, 20 }) }))
    t.eq(ev.result, R.REPRODUCED, "two counted links at different gaps: reproduced")
    t.eq(ev.measured_summary.rule, "combo_links", "  by the combo rule")
    t.eq(ev.measured_summary.combo_status, "confirmed", "  which SweepReport calls confirmed")
    t.eq(ev.combo.moves_key, "660>655>900", "  shown as its moves")
    t.eq(ev.combo.notation_chain, "AUTO + 强 > 3 + 中 > 2 + SP", "  and its notations")

    ev = only(evaluate({ route_run("link", { 40, 2 }), route_run("wrong_move", { 40, 4 }) }))
    t.eq(ev.result, R.OBSERVED_SUCCESS, "one link: observed_success")
    ev = only(evaluate({ route_run("link", { 40, 2 }), route_run("whiff", { 40, 4 }) }))
    t.eq(ev.result, R.MIXED, "one link and a failure: mixed")
    ev = only(evaluate({ route_run("link", { 40, 2 }), route_run("link", { 40, 4 }), route_run("whiff", { 40, 6 }) }))
    t.eq(ev.result, R.REPRODUCED, "two links and a failure: reproduced")
    ev = only(evaluate({ route_run("link", { 40, 2 }), route_run("link", { 40, 4 }, { quality_flags = { F.SUPERSEDED_RERUN } }) }))
    t.eq(ev.result, R.OBSERVED_SUCCESS, "a superseded link is not the second link")
    ev = only(evaluate({ route_run("link", { 40, 2 }, { quality_flags = { F.LEGACY_ROUTE_SUBJECT, F.EVIDENCE_MISSING } }),
                         route_run("link", { 40, 4 }, { quality_flags = { F.LEGACY_ROUTE_SUBJECT } }) }))
    t.eq(ev.result, R.REPRODUCED, "legacy route rows count like any others")

    ev = only(evaluate({ route_run("link", { 44, 2 }), route_run("link", { 40, 10 }), route_run("link", { 40, 2 }) }))
    t.eq(table.concat(ev.measured_summary.linked_gaps, " "), "40,2 40,10 44,2", "linked gaps sort by their numbers")
    t.eq(ev.measured_summary.by_delay["40,10"].successes, 1, "by_delay keyed by the delay list")

    local evs = evaluate({ route_run("link", { 40, 2 }), run("link", 4) })
    t.eq(#evs, 2, "a route and a pair are separate subjects")
end

-- --- measured summary --------------------------------------------------------------------------

t.group("measured summary")

do
    local ev = only(evaluate({
        route_run("link", { 40, 2 }, { measured_damage = 2400 }),
        route_run("link", { 40, 4 }, { measured_damage = 2600 }),
        route_run("link", { 40, 6 }, { measured_damage = 9999, quality_flags = { F.SUPERSEDED_RERUN } }),
        route_run("whiff", { 40, 8 }, { measured_damage = 100 }),
    }))
    t.eq(ev.measured_summary.damage.samples, 2, "damage from counted links only")
    t.eq(ev.measured_summary.damage.min, 2400, "  min")
    t.eq(ev.measured_summary.damage.max, 2600, "  max (the superseded 9999 and the whiff are not in it)")
    ev = only(evaluate({ run("link", 4) }))
    t.is_nil(ev.measured_summary.damage, "no measured damage: no damage block, not zero")
end

-- --- problems ------------------------------------------------------------------------------------

t.group("what cannot be evaluated is a problem")

do
    local a = run("link", 4)
    local evs, problems = E.evaluate({ a, a })
    t.eq(#problems, 1, "the same event_key twice is a problem")
    local bad = run("link", 4); bad.answers = "negative"
    evs, problems = E.evaluate({ bad })
    t.eq(#problems, 1, "answers that do not follow the verdict is a problem")
    t.eq(#evs, 0, "  and no evaluation is made from it")
    local odd = run("link", 4, { quality_flags = { "brand_new_flag" } })
    evs, problems = E.evaluate({ odd, run("link", 4, { attempt = 2 }) })
    t.eq(#evs, 0, "a group with an unclassified flag produces no evaluation (a partial evidence set)")
    t.eq(#problems, 1, "  and one problem")
    local tally = E.tally(evaluate({ run("link", 4), run("whiff", 8, { quality_flags = { F.FIXED_DELAY_4 } }), route_run("link", { 40, 2 }) }))
    t.eq(tally.by_kind_result["edge:observed_success"], 1, "tally by kind and result")
    t.eq(tally.excluded_by_reason[F.FIXED_DELAY_4], 1, "tally by exclusion reason")
end

return t.finish()
