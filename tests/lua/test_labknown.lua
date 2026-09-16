-- Unit tests for tools/lua/labknown.lua, and for the statuses
-- tools/lua/planner.lua folds out of the evaluations it produces.
--
-- This is the path that decides what the page and the plan BELIEVE about a
-- negative. Before it, any "no" in any cohort made a pair `rejected`, a route
-- through it was demoted, and 352 of the 856 committed runs were answers to a
-- question nobody asked. So the things pinned here are the ways that could come
-- back:
--
--   a pair whose only negatives were excluded must not be rejected
--   a superseded run that LINKED must still count
--   a pair reproduced on the counted runs must be verified
--   only a conclusive failure may demote a route
--   the same observation committed twice must be one run, with both flag sets
--
-- The evaluations are made by the real tools/lua/labeval.lua over rows built by
-- the real tools/lua/labrows.lua: a fake evaluation would pin this file's idea
-- of the policy rather than the policy.

local t = require("tests.lua.harness")
dofile("tools/lua/cli.lua")
local json = dofile("tools/lua/json.lua")
local LK = dofile("tools/lua/labknown.lua")
local P = dofile("tools/lua/planner.lua")

local CONDITIONS = {
    schema = "ce.conditions.v1",
    canonical = "positions=controlled:p1=?,p2=?,tol=0.5;resources=unpinned;counter=unknown;screen=unknown;opponent=?",
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

-- One pair trial. `over` replaces any field.
local function trial(edge, delay, verdict, attempt, over)
    local answers = (verdict == "link") and "positive"
        or ((verdict == "whiff" or verdict == "combo_broke") and "negative" or "unanswered")
    local r = {
        schema = "ce.trial.v1",
        id = ("%s @ %d #%d %s"):format(edge, delay, attempt, verdict),
        edge_id = edge, subject_kind = "edge", subject_id = edge,
        delay = delay, delays = { delay }, attempt = attempt,
        verdict = verdict, answers = answers,
        evidence = { verdict = verdict, a_hit = true },
        provenance = { calibration_id = "CAL-1", game_patch = "24176760" },
        character = "Zangief", control_scheme = "modern",
        conditions = copy(CONDITIONS),
        recorded_at = "2026-09-12T12:00:00Z",
    }
    for k, v in pairs(over or {}) do r[k] = v end
    return r
end

-- A file as M.load_trials would have read it.
local function file(path, records)
    local out = {}
    for i, rec in ipairs(records) do out[i] = { line_no = i, record = rec } end
    return { path = "reframework/data/ComboExplorer_data/trials/" .. path,
             base = path, records = out, bad_lines = 0 }
end

-- --- reading a log the way the importer reads it -----------------------------------

t.group("scan_trials")

local text = table.concat({
    json.encode(trial("601:manual->604:manual", 10, "link", 1)),
    "",
    "{not json",
    json.encode(trial("601:manual->604:manual", 10, "link", 2)),
}, "\n")   -- no trailing newline: the last line is unterminated

local scanned, bad = LK.scan_trials(text)
t.eq(#scanned, 1, "an unterminated last line is not believed, and a blank is not a line")
t.eq(bad, 2, "the undecodable line and the unterminated one are counted, not dropped")
t.eq(scanned[1].line_no, 1, "line numbers are the file's, from 1")

scanned = LK.scan_trials(text .. "\n")
t.eq(#scanned, 2, "with a terminator the last line is read")
t.eq(scanned[2].line_no, 4, "and keeps its own line number")

t.group("event_key: the same observation is one run")

local dup = trial("601:manual->604:manual", 10, "link", 1)
t.eq(LK.event_key(copy(dup)), LK.event_key(copy(dup)),
    "two decodings of one record have one key")
t.ok(LK.event_key(dup) ~= LK.event_key(trial("601:manual->604:manual", 10, "link", 2)),
    "a different attempt is a different observation")

-- The same line committed in two files: one run, both locations. The fixed-gap
-- file's rule applies to its copy, so the union carries fixed_delay_4 and the
-- evaluation must see it.
local shared = trial("601:manual->604:manual", 4, "whiff", 1)
local rows, problems, counts = LK.rows({
    file("zangief-modern-other.jsonl", { copy(shared) }),
    file("zangief-modern-delay4.jsonl", { copy(shared) }),
})
t.eq(#problems, 0, "no problems: " .. table.concat(problems, "; "))
t.eq(counts.rows, 1, "one run")
t.eq(counts.duplicates, 1, "and one duplicate location")
t.eq(#rows[1].sources, 2, "the run names both files")

local evs = LK.evaluate(rows)
t.eq(#evs, 1, "one evaluation")
t.eq(evs[1].conclusive_failures, 0,
    "a flag on ONE location is a flag on the run: the whiff is excluded")
t.eq(evs[1].excluded_runs, 1, "and counted as excluded")

-- --- the three rules the plan rests on --------------------------------------------

t.group("a negative the policy threw out is not a rejection")

local only_bad = LK.from_files({
    file("zangief-modern-delay4.jsonl", {
        trial("601:manual->604:manual", 4, "whiff", 1),
        trial("601:manual->604:manual", 4, "whiff", 2),
    }),
})
t.eq(#only_bad, 1, "one evaluation")
t.eq(only_bad[1].result, "pending", "labeval: nothing counted answered")
t.eq(only_bad[1].excluded_runs, 2, "both runs left out")

local known = P.known_from(nil, nil, nil, only_bad)
local k = known.pairs["601:manual->604:manual"]
t.eq(k.status, "asked_badly", "the plan calls it asked_badly, NOT rejected")
t.eq(k.policy.excluded_negatives, 2, "and says how many negatives were thrown out")

t.group("a conclusive negative IS a rejection")

local real_no = LK.from_files({
    file("zangief-modern-framedata.jsonl", {
        trial("601:manual->604:manual", 20, "whiff", 1),
        trial("601:manual->604:manual", 22, "whiff", 1),
    }),
})
t.eq(real_no[1].result, "no_success_observed", "labeval: counted failures and no link")
t.eq(P.known_from(nil, nil, nil, real_no).pairs["601:manual->604:manual"].status, "rejected",
    "and the plan rejects it")

t.group("a superseded run that linked still counts")

-- The same resume key in both files, so labrows flags the older row. One of the
-- two links lives in the superseded file: without rule 1's "unless it linked"
-- the pair would never be reproduced, which is what the first draft of the
-- policy did to four of five pair combos on the committed logs.
local SUP = "zangief-modern-framedata-singleid.jsonl"
local NEW = "zangief-modern-framedata.jsonl"
-- The re-run's rows are the same experiment recorded again, not the same
-- observation: a different recorded_at, so they are separate runs rather than
-- one merged by event_key.
local function later(rec) rec.recorded_at = "2026-09-13T09:00:00Z" return rec end
local sup_evs, sup_problems = LK.from_files({
    file(SUP, {
        trial("601:manual->604:manual", 20, "link", 1),
        trial("601:manual->604:manual", 20, "whiff", 2),
    }),
    file(NEW, {
        later(trial("601:manual->604:manual", 20, "link", 1)),
        later(trial("601:manual->604:manual", 20, "link", 2)),
    }),
})
t.eq(#sup_problems, 0, "no problems: " .. table.concat(sup_problems, "; "))
t.eq(#sup_evs, 1, "one pair, one cohort, one evaluation")
t.eq(sup_evs[1].successful_runs, 3, "the superseded link counts beside the two re-run links")
t.eq(sup_evs[1].conclusive_failures, 0, "and the superseded whiff does not")
t.eq(sup_evs[1].excluded_runs, 1, "which is one run excluded")
t.eq(sup_evs[1].result, "reproduced", "so the pair is reproduced")

local sup_known = P.known_from(nil, nil, nil, sup_evs)
t.eq(sup_known.pairs["601:manual->604:manual"].status, "verified",
    "a reproduced pair is verified")

t.group("a pair that linked once is neither verified nor rejected")

local once = LK.from_files({
    file(NEW, {
        trial("601:manual->604:manual", 20, "link", 1),
        trial("601:manual->604:manual", 22, "link", 1),
    }),
})
t.eq(once[1].result, "observed_success", "labeval: links, never twice at one delay")
local once_known = P.known_from(nil, nil, nil, once)
t.eq(once_known.pairs["601:manual->604:manual"].status, "linked_once",
    "the plan calls it linked_once")

t.group("nothing at all is pending, not asked_badly")

local nothing = LK.from_files({
    file(NEW, { trial("601:manual->604:manual", 20, "wrong_move", 1) }),
})
t.eq(nothing[1].result, "pending", "an unanswered run answers nothing")
t.eq(P.known_from(nil, nil, nil, nothing).pairs["601:manual->604:manual"].status, "pending",
    "and no negative was thrown out, so it is plain pending")

-- --- what the plan does with them ---------------------------------------------------

t.group("only a conclusive failure demotes a route")

local function mv(id, notation)
    return { action_id = id, notation = notation, input_method = "manual" }
end
local function route(id, steps, damage)
    return { id = id, steps = steps, offline_score = {
        route_length = #steps, od_steps = 0, super_steps = 0, drive_rush_cancel_steps = 0,
        predicted_drive_spend = 0, drive_spend_known = true, drive_spend_unknown_steps = 0,
        predicted_super_spend = 0, predicted_damage = damage, execution_cost = 5,
        theoretical_confidence = "medium" } }
end

local mixed_evs = LK.from_files({
    -- 601 -> 604: every negative thrown out by the fixed-gap rule.
    file("zangief-modern-delay4.jsonl", {
        trial("601:manual->604:manual", 4, "whiff", 1),
        trial("601:manual->604:manual", 4, "whiff", 2),
    }),
    -- 601 -> 640: asked properly, and the answer was no.
    file(NEW, {
        trial("601:manual->640:manual", 20, "whiff", 1),
        trial("601:manual->640:manual", 22, "whiff", 1),
    }),
})
local mixed_known = P.known_from(nil, nil, nil, mixed_evs)
local A = route("a", { mv(601, "x"), mv(604, "y") }, 100)   -- through the asked_badly pair
local B = route("b", { mv(601, "x"), mv(640, "z") }, 200)   -- through the rejected pair

local plan = P.plan({ A, B }, { sort = "damage", top = 2, known = mixed_known })
t.eq(plan.through_rejected, 1, "exactly one route is through a rejected pair")
t.eq(plan.routes[2].id, "b", "b outranks a on damage and is still demoted behind it")
t.eq(plan.routes[2].sort_rank, 1, "the sort had it first")
t.eq(plan.routes[2].has_rejected_pair, true, "because its pair was conclusively rejected")
t.eq(plan.routes[1].id, "a", "the route through the asked_badly pair keeps the top")
t.eq(plan.routes[1].has_rejected_pair, false, "it is NOT demoted")
t.eq(#plan.routes[1].asked_badly_pairs, 1, "it is named as never asked properly instead")

local sweep_keys = {}
for i, p in ipairs(plan.sweep) do sweep_keys[i] = p.key end
table.sort(sweep_keys)
t.eq_list(sweep_keys, { "601:manual->604:manual", "601:manual->640:manual" },
    "both pairs are asked again")

t.group("reclassified: both answers are kept")

-- The raw ConfirmedEdge answer beside the policy's, so a report can say how far
-- the policy moved things.
local raw = { edge_id = "601:manual->604:manual", status = "rejected", stable = true,
              attempts = 2, successes = 0, negatives = 2, unanswered = 0,
              cohort = { calibration_id = "CAL-1" } }
local both = P.known_from({ raw }, nil, nil, only_bad)
t.eq(both.pairs["601:manual->604:manual"].raw_status, "rejected",
    "the old rule still says rejected")
t.eq(both.pairs["601:manual->604:manual"].status, "asked_badly", "the policy says otherwise")
t.eq(both.reclassified.total, 1, "and the change is counted")
t.eq(both.reclassified.moves["rejected -> asked_badly"], 1, "by what it changed to")

local no_policy = P.known_from({ raw })
t.eq(no_policy.uses_policy, false, "with no evaluations the policy is not in play")
t.eq(no_policy.pairs["601:manual->604:manual"].status, "rejected",
    "and the old rule decides, exactly as before")
t.eq(no_policy.reclassified.total, 0, "nothing is reported as reclassified")

t.group("the confirmed badge follows the policy, not the looser count")

-- sweepreport's list says confirmed (two links anywhere); the policy counted
-- neither of them at one delay, so the badge must not.
local combos = { { key = "601>604", status = "confirmed",
                   inputs = { { "x", "y" } } } }
local loose_known = P.known_from(nil, combos, nil, once)
local ann = P.annotate(nil, { A }, loose_known)
t.eq(ann.routes[1].combo_status, "confirmed", "the looser status is carried")
t.eq(ann.routes[1].combo_policy, "observed_success", "beside the policy's result")
t.eq(ann.routes[1].confirmed, false, "and the badge is the policy's")

local strong_known = P.known_from(nil, combos, nil, sup_evs)
t.eq(P.annotate(nil, { A }, strong_known).routes[1].confirmed, true,
    "a reproduced combo is confirmed")

local legacy = P.annotate(nil, { A }, P.known_from(nil, combos))
t.eq(legacy.routes[1].confirmed, true,
    "with no evaluations the badge falls back to the looser list")

t.group("exclusions, for the report line")

local ex = LK.exclusions(mixed_evs)
t.eq(ex.excluded, 2, "two runs left out")
t.eq(ex.counted, 2, "two counted")
t.eq(ex.negatives_excluded, 2, "both of them negatives")
t.eq(ex.by_reason["fixed_delay_4"], 2, "named by the reason the policy recorded")

return t.finish()
