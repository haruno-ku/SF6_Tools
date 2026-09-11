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
    for k, v in pairs(over or {}) do rec[k] = v end
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

return t.finish()
