-- Unit tests for func/ComboExplorer/core/ConfirmedEdge.lua
--
-- This is the link that was missing between "the sweep ran" and "here are the
-- combos that work", so the things worth pinning are the ways it could quietly
-- lie:
--
--   calling one attempt a reproduction
--   counting a trial that answered nothing as a failure
--   claiming a delay window wider than the delays anybody tried
--
-- The last two are the same mistake in different clothes: filling a gap with a
-- conclusion instead of leaving it open.

local t = require("tests.lua.harness")
local CE = require("func/ComboExplorer/core/ConfirmedEdge")
local Schema = require("func/ComboExplorer/core/Schema")

local EDGE = "601:manual->621:manual"

-- A key set to nil in a table constructor is not there at all, so an override
-- that removes a field is spelled with this marker.
local NONE = {}

local function trial(verdict, delay, over)
    local rec = {
        schema = Schema.KIND.TRIAL,
        id = ("edge %s @ %s #1"):format(EDGE, tostring(delay)),
        edge_id = EDGE,
        verdict = verdict,
        delay = delay,
        attempt = 1,
        status = Schema.STATUS.VERIFIED,
        recorded_at = "2026-09-11T12:00:00Z",
        provenance = { calibration_id = "cal-test", game_patch = "p" },
    }
    for k, v in pairs(over or {}) do
        if v == NONE then rec[k] = nil else rec[k] = v end
    end
    return rec
end

-- --- one attempt is not a reproduction -------------------------------------------

t.group("a single trial is never stable")

do
    local e, why = CE.fold({ trial("link", 4) })
    t.ok(e ~= nil, "one linking trial folds: " .. tostring(why))
    t.eq(e.status, Schema.STATUS.VERIFIED, "and the pair is verified - it did link")
    t.eq(e.stable, false, "but NOT stable, because it happened once")
    t.eq(e.attempts, 1, "one attempt")
    t.eq(e.successes, 1, "one success")
    t.ok(tostring(e.reason):find("never twice") ~= nil,
         "and it says so: " .. tostring(e.reason))

    -- Schema refuses a verified edge that is neither stable nor knowingly
    -- unstable. That refusal is the point: it is what stops a one-off fluke
    -- entering the published list with the same standing as a repeated link.
    local ok = Schema.validate(Schema.KIND.CONFIRMED, e)
    t.eq(ok, false, "so the schema refuses it until somebody says they mean it")

    local said, _ = CE.fold({ trial("link", 4) }, { unstable_ok = true })
    t.eq(said.unstable_ok, true, "and unstable_ok is how they say it")
    t.eq(Schema.validate(Schema.KIND.CONFIRMED, said), true,
         "which the schema then accepts")
end

do
    -- Two at the SAME delay is a reproduction.
    local e = CE.fold({ trial("link", 4), trial("link", 4) })
    t.eq(e.stable, true, "two linking attempts at one delay is reproduced")
    t.eq(Schema.validate(Schema.KIND.CONFIRMED, e), true, "and the schema accepts it")
end

do
    -- Two at DIFFERENT delays is not. That is two experiments run once each,
    -- and counting them together would call a pair stable on the strength of
    -- never having repeated anything.
    local e = CE.fold({ trial("link", 4), trial("link", 5) })
    t.eq(e.successes, 2, "both linked")
    t.eq(e.stable, false, "but neither was repeated, so it is not stable")
end

-- --- unanswered is not negative ----------------------------------------------------

t.group("a trial that answered nothing is not a failure")

-- This is the failure the whole project is built to avoid, and it would be easy
-- to write: `successes < attempts` reads like a fair test for "did not work".

do
    local e = CE.fold({ trial("a_failed", 4), trial("a_failed", 4), trial("wrong_move", 4) })
    t.eq(e.attempts, 3, "the attempts are counted - the time was spent")
    t.eq(e.successes, 0, "none linked")
    t.eq(e.negatives, 0, "and NONE of them is a negative")
    t.eq(e.unanswered, 3, "they are unanswered")
    t.eq(e.status, Schema.STATUS.RUNTIME_PENDING,
         "so the pair stays an open question rather than becoming a rejection")
    t.eq(e.stable, false, "and nothing about it is settled")
end

do
    -- Mixed: one real negative, the rest unanswered. The answer rests on the
    -- one trial that answered.
    local e = CE.fold({ trial("whiff", 4), trial("a_failed", 4), trial("inconclusive", 4) })
    t.eq(e.status, Schema.STATUS.REJECTED, "one conclusive negative rejects the pair")
    t.eq(e.negatives, 1, "counted as the single negative it is")
    t.eq(e.unanswered, 2, "with the other two left as unanswered")
    t.eq(e.stable, false, "and one negative is not a reproduction either")
end

do
    local e = CE.fold({ trial("whiff", 4), trial("blocked", 4) })
    t.eq(e.status, Schema.STATUS.REJECTED, "two conclusive negatives reject it")
    t.eq(e.stable, true, "and that is reproduced")
end

-- --- the delay window is what was measured -------------------------------------------

t.group("the window never claims a delay nobody tried")

do
    -- 3, 4, 5 all linked; 6 did not.
    local e = CE.fold({ trial("link", 3), trial("link", 4), trial("link", 5),
                        trial("whiff", 6) })
    t.ok(e.window ~= nil, "a window was measured")
    t.eq(e.window.from, 3, "starting at the first delay that linked")
    t.eq(e.window.to, 5, "ending at the last")
    t.eq(e.window.count, 3, "over three tried values")
    t.eq(e.window.tried_count, 4, "out of four delays tried in all")
end

do
    -- Tried 2, 4 and 6, linked at all three. That is three POINTS, not a
    -- five-frame window: claiming the gap would be inventing the trials at 3
    -- and 5 that nobody ran.
    local e = CE.fold({ trial("link", 2), trial("link", 4), trial("link", 6) })
    t.eq(e.window.count, 3, "three values linked")
    t.eq(e.window.from, 2, "from the lowest")
    t.eq(e.window.to, 6, "to the highest")
    t.eq(e.window.contiguous_over_tried_values, true,
         "and the window says it is contiguous over TRIED values, not over frames")
end

do
    local e = CE.fold({ trial("whiff", 3), trial("whiff", 4) })
    t.is_nil(e.window, "a pair that never linked has no window at all")
end

do
    -- The longest RUN, not the total. 3 links, 4 does not, 5 and 6 link.
    local e = CE.fold({ trial("link", 3), trial("whiff", 4),
                        trial("link", 5), trial("link", 6) })
    t.eq(e.window.count, 2, "the widest unbroken run is two")
    t.eq(e.window.from, 5, "the later pair")
    t.eq(e.window.to, 6, "not the isolated earlier one")
end

-- --- refusals -------------------------------------------------------------------------

t.group("what it will not read")

do
    local nope, why = CE.fold({})
    t.is_nil(nope, "no trials, no edge")
    t.ok(tostring(why):find("no trials") ~= nil, tostring(why))

    local bad, bwhy = CE.fold({ trial("link", 4, { verdict = "sort_of" }) })
    t.is_nil(bad, "an unrecognised verdict is refused rather than filed as unanswered")
    t.ok(tostring(bwhy):find("unknown verdict") ~= nil,
         "through the collector's own vocabulary: " .. tostring(bwhy))

    local mixed, mwhy = CE.fold({ trial("link", 4),
                                  trial("link", 4, { edge_id = "other" }) })
    t.is_nil(mixed, "trials for two different pairs will not fold together")
    t.ok(tostring(mwhy):find("two different pairs") ~= nil, tostring(mwhy))

    local notrial, nwhy = CE.fold({ { schema = "ce.route.v1" } })
    t.is_nil(notrial, "a record that is not a trial is refused")
    t.ok(tostring(nwhy):find("not a trial") ~= nil, tostring(nwhy))
end

-- --- the whole log ----------------------------------------------------------------------

t.group("a log of many pairs")

do
    local recs = {
        trial("link", 4),
        trial("link", 4),
        trial("whiff", 4, { edge_id = "601:manual->700:manual" }),
        trial("whiff", 4, { edge_id = "601:manual->700:manual" }),
        trial("a_failed", 4, { edge_id = "601:manual->701:manual" }),
        { schema = "ce.route.v1" },            -- not a trial
    }
    local edges, problems, counts = CE.from_trials(recs)

    t.eq(#edges, 3, "one edge per pair")
    t.eq(counts.verified, 1, "one verified")
    t.eq(counts.rejected, 1, "one rejected")
    t.eq(counts.pending, 1, "one still open")
    t.eq(counts.stable, 2, "two of them reproduced")

    t.eq(#problems, 1, "and the record that is not a trial is a problem, not a silent drop")
    t.ok(tostring(problems[1].reason):find("not a trial") ~= nil, "with its reason")

    -- Sorted, so two runs over the same log produce the same file.
    local ids = {}
    for _, e in ipairs(edges) do ids[#ids + 1] = e.edge_id end
    local sorted = true
    for i = 2, #ids do if ids[i] < ids[i - 1] then sorted = false end end
    t.eq(sorted, true, "the output is ordered")

    for _, e in ipairs(edges) do
        if e.status ~= Schema.STATUS.RUNTIME_PENDING then
            t.eq(e.runtime_verified, true,
                 e.edge_id .. " rests on trials that ran on the game")
            t.ok(type(e.evidence) == "table", e.edge_id .. " carries its evidence")
        end
    end
end

-- --- route runs are not pairs (#14) ------------------------------------------------------

t.group("a route run is not folded as a pair")

-- Route runs used to be recorded as fake edges, "<route>@<gaps>", and this
-- function folds every edge id it is handed. A route that linked at several
-- gap combinations would have come out as that many verified "pairs".
do
    local function route_row(verdict, gaps, over)
        local o = { edge_id = NONE, delays = gaps, subject_kind = "route",
                    subject_id = "gt", route_id = "gt" }
        for k, v in pairs(over or {}) do o[k] = v end
        return trial(verdict, nil, o)
    end
    local recs = {
        trial("link", 4, { subject_kind = "edge", subject_id = EDGE }),
        trial("link", 4, { subject_kind = "edge", subject_id = EDGE }),
        route_row("link", { 40, 2 }),
        route_row("link", { 40, 4 }),
        route_row("whiff", { 44, 2 }),
        -- The committed shape: subject_kind "edge", and an edge id that is a
        -- route with its gaps appended.
        route_row("link", { 40, 2 }, { subject_kind = "edge", subject_id = "old@40/2",
                                       edge_id = "old@40/2", route_id = NONE }),
        route_row("link", { 40, 4 }, { subject_kind = "edge", subject_id = "old@40/4",
                                       edge_id = "old@40/4", route_id = NONE }),
    }
    local edges, problems, counts = CE.from_trials(recs)

    t.eq(#edges, 1, "the pair is folded and nothing else is")
    t.eq(edges[1].edge_id, EDGE, "the real pair")
    t.eq(edges[1].attempts, 2, "with only its own trials in it")
    t.eq(counts.route_trials, 5, "every route row is counted, so none is silently dropped")
    t.eq(counts.routes, 2, "across the two routes")

    local by_route = {}
    for _, p in ipairs(problems) do
        if p.kind == "route" then by_route[p.route_id] = p end
    end
    t.ok(by_route.gt ~= nil, "a route that says it is a route is reported as not folded")
    t.eq(by_route.gt and by_route.gt.trials, 3, "once, with its row count")
    t.eq(by_route.gt and by_route.gt.legacy, false, "written under the subject contract")
    t.ok(by_route.old ~= nil, "a legacy fake edge is recognised as its route")
    t.eq(by_route.old and by_route.old.trials, 2, "all of its rows")
    t.eq(by_route.old and by_route.old.legacy, true, "and marked as the old spelling")
    t.eq(#problems, 2, "one entry per route, not one per row")

    local nope, why = CE.fold({ route_row("link", { 40, 2 }) })
    t.is_nil(nope, "fold refuses a route row outright")
    t.ok(tostring(why):find("not a trial of a pair") ~= nil, tostring(why))

    local noid, nwhy = CE.fold({ trial("link", 4, { edge_id = NONE }) })
    t.is_nil(noid, "a trial that names no subject at all is refused")
    t.ok(tostring(nwhy):find("does not say what it is about") ~= nil, tostring(nwhy))
end

do
    -- Pairs recorded under the subject contract fold by their subject, whether
    -- or not the optional edge_id is spelled out.
    local edges = CE.from_trials({
        trial("link", 4, { subject_kind = "edge", subject_id = EDGE }),
        trial("link", 4, { subject_kind = "edge", subject_id = EDGE, edge_id = NONE }),
    })
    t.eq(#edges, 1, "an edge row without edge_id folds with one that has it")
    t.eq(edges[1] and edges[1].attempts, 2, "into the same pair")
end

-- --- one cohort at a time ---------------------------------------------------------------

t.group("trials measured under different conditions do not fold together")

-- #38 names this function by name: it grouped on edge_id alone and took the
-- first record's provenance, so a log holding two experiments produced one
-- number averaged over both with nothing to say it had happened.
--
-- It is not a hypothetical. Redoing the calibration mid-session changes
-- calibration_id.

local TestContext = require("func/ComboExplorer/core/TestContext")

local LOOSE = TestContext.of({ stage = { target_positions = false, pin = false } })
local PINNED = TestContext.of({ stage = { target_positions = false,
                                          pin = { attacker_super = 3 } } })

do
    -- Same pair, same delay. One calibration says it links, the other says it
    -- whiffs. Folded together that is "linked at some delays and not others";
    -- folded apart it is two answers about two setups, which is the truth.
    local recs = {
        trial("link", 4, { provenance = { calibration_id = "cal-A", game_patch = "p" } }),
        trial("link", 4, { provenance = { calibration_id = "cal-A", game_patch = "p" } }),
        trial("whiff", 4, { provenance = { calibration_id = "cal-B", game_patch = "p" } }),
        trial("whiff", 4, { provenance = { calibration_id = "cal-B", game_patch = "p" } }),
    }
    local edges, problems, counts, cohorts = CE.from_trials(recs)

    t.eq(#edges, 2, "one pair measured under two calibrations produces TWO edges")
    t.eq(counts.cohorts, 2, "and the count says how many experiments are in the log")
    t.eq(#cohorts, 2, "with the cohorts themselves reported")
    t.eq(#problems, 0, "and nothing was dropped to achieve it")

    local by_status = {}
    for _, e in ipairs(edges) do by_status[e.status] = (by_status[e.status] or 0) + 1 end
    t.eq(by_status[Schema.STATUS.VERIFIED], 1, "one cohort says it links")
    t.eq(by_status[Schema.STATUS.REJECTED], 1, "the other says it does not")

    -- The ids have to differ or a later reader keeps one and loses the other.
    t.ok(edges[1].id ~= edges[2].id, "and the two rows have different ids")
    t.eq(edges[1].edge_id, edges[2].edge_id, "while naming the same pair")
    t.ok(edges[1].cohort_key ~= edges[2].cohort_key, "under different cohorts")
    t.ok(edges[1].cohort.calibration_id ~= edges[2].cohort.calibration_id,
         "and each row says which calibration it rests on")
end

do
    -- The conditions split a cohort too, which is the case that matters after
    -- today: same calibration, gauges pinned for one pass and loose for the
    -- other.
    local recs = {
        trial("link", 4, { conditions = LOOSE }),
        trial("link", 4, { conditions = LOOSE }),
        trial("whiff", 4, { conditions = PINNED }),
    }
    local edges, _, counts = CE.from_trials(recs)
    t.eq(#edges, 2, "pinned and loose are two experiments")
    t.eq(counts.cohorts, 2, "counted as two cohorts")
end

do
    -- And two trials that ARE the same experiment still fold into one.
    local recs = {
        trial("link", 4, { conditions = LOOSE }),
        trial("link", 4, { conditions = TestContext.of({
            stage = { target_positions = false, pin = false } }) }),
    }
    local edges, _, counts = CE.from_trials(recs)
    t.eq(#edges, 1, "the same conditions in a different table are the same cohort")
    t.eq(counts.cohorts, 1, "so there is one experiment here")
    t.eq(edges[1].stable, true, "and the two attempts reproduce each other")
end

do
    -- fold() refuses a mixed handful outright, the same way it refuses two
    -- different pairs. A function returning one answer must not be handed two
    -- experiments.
    local mixed, why = CE.fold({
        trial("link", 4, { provenance = { calibration_id = "cal-A", game_patch = "p" } }),
        trial("link", 4, { provenance = { calibration_id = "cal-B", game_patch = "p" } }),
    })
    t.is_nil(mixed, "fold will not average two cohorts into one edge")
    t.ok(tostring(why):find("two different cohorts") ~= nil, tostring(why))
end

do
    -- A patch boundary is a cohort boundary: a link measured on last month's
    -- build is not evidence about this one.
    local recs = {
        trial("link", 4, { provenance = { calibration_id = "c", game_patch = "24176760" } }),
        trial("link", 4, { provenance = { calibration_id = "c", game_patch = "24200000" } }),
    }
    local edges, _, counts = CE.from_trials(recs)
    t.eq(counts.cohorts, 2, "two patches are two cohorts")
    t.eq(#edges, 2, "and neither borrows the other's evidence")
    for _, e in ipairs(edges) do
        t.eq(e.stable, false, "so neither is stable on one attempt")
    end
end

do
    -- The character matters even though the pair is named by action ids: ids
    -- are only meaningful against one catalog, and two characters can carry the
    -- same number for entirely different moves.
    local recs = {
        trial("link", 4, { character = "Zangief", control_scheme = "modern" }),
        trial("whiff", 4, { character = "Ryu", control_scheme = "modern" }),
    }
    local edges, _, counts = CE.from_trials(recs)
    t.eq(counts.cohorts, 2, "two characters are two cohorts")
    t.eq(#edges, 2, "so 601 on Zangief is not evidence about 601 on Ryu")

    -- And so does the control scheme: the same action under Modern and Classic
    -- is a different input with different scaling.
    local schemes = {
        trial("link", 4, { character = "Zangief", control_scheme = "modern" }),
        trial("whiff", 4, { character = "Zangief", control_scheme = "classic" }),
    }
    local sedges, _, scounts = CE.from_trials(schemes)
    t.eq(scounts.cohorts, 2, "Modern and Classic are two cohorts")
    t.eq(#sedges, 2, "and neither answers for the other")
end

return t.finish()
