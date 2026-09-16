-- Unit tests for tools/lua/verifiedcombo.lua - the step that turns a lab
-- evaluation into a ce.verified_combo.v1, or refuses to.
--
-- Every evaluation here is made by the REAL tools/lua/labeval.lua over runs in
-- the shape the importer hands over, for the reason test_labknown gives: a
-- hand-written evaluation would pin this file's idea of the policy instead of
-- the policy.
--
-- What is pinned, and why each one could come back:
--
--   a reproduced subject with an agreed damage figure becomes a record the
--     schema accepts - and if it does not, that is a defect here, which is the
--     one failure this module is required to surface as a bug
--   a reproduced subject with NO damage produces no record, goes on the refused
--     list with the reason, and never gets a zero
--   two counted links that read different damage are refused, not averaged
--   observed_success is not published: one link is not a combo
--   the gauges travel when the runs have them, and are absent when they do not
--   KnowledgeDb's own gate refusals arrive with their reasons and their
--     missing_moves, because that list is what the slug table is built from

local t = require("tests.lua.harness")
dofile("tools/lua/cli.lua")
local E      = dofile("tools/lua/labeval.lua")
local VC     = dofile("tools/lua/verifiedcombo.lua")
local Schema = require("func/ComboExplorer/core/Schema")
local KDB    = require("func/ComboExplorer/core/KnowledgeDb")

local CANON = "positions=controlled:p1=?,p2=?,tol=0.5;resources=unpinned;counter=unknown;screen=unknown;opponent=?"
local EDGE = "617:manual->1206:manual"
local PATCH, CAL = "24176760", "CAL-B"

local ANSWER = { link = "positive", whiff = "negative", wrong_move = "unanswered" }

local seq = 0
local function run(verdict, delay, over)
    seq = seq + 1
    local r = {
        kind = "run",
        event_key = ("sha256:%064d"):format(seq),
        schema = "ce.trial.v1",
        character = "Zangief", control_scheme = "modern",
        game_patch = PATCH, calibration_id = CAL,
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

local function evaluate(runs)
    local evs, problems = E.evaluate(runs)
    t.eq(#(problems or {}), 0, "no evaluation problems: " .. table.concat(problems or {}, "; "))
    return evs or {}
end

-- Two links at one delay: what ConfirmedEdge calls stable, which is what the
-- policy calls reproduced.
local function reproduced(over_a, over_b)
    return evaluate({ run("link", 22, over_a), run("link", 22, over_b) })
end

local function first_of(records, refused)
    return records[1], refused[1]
end

-- --- a reproduced subject with a measurement ---------------------------------

t.group("a reproduced subject with an agreed damage figure becomes a record")

do
    local evs = reproduced({ measured_damage = 2400, measured_hits = 2 },
                           { measured_damage = 2400, measured_hits = 2 })
    t.eq(#evs, 1, "one evaluation")
    t.eq(evs[1].result, E.RESULT.REPRODUCED, "  which reproduced")

    local records, refused, counts = VC.build(evs)
    t.eq(#records, 1, "one record")
    t.eq(#refused, 0, "nothing refused")
    t.eq(counts.records, 1, "counted as produced")
    t.eq(counts.bugs, 0, "no record the schema refused")

    local rec = records[1]
    local ok, problems = Schema.validate(Schema.KIND.COMBO, rec)
    t.ok(ok, "the schema accepts it: " .. (ok and "" or problems[1].field .. " " .. problems[1].problem))
    t.eq(rec.schema, Schema.KIND.COMBO, "  tagged ce.verified_combo.v1")
    t.eq(rec.status, Schema.STATUS.VERIFIED, "  status verified")
    t.eq(rec.runtime_verified, true, "  runtime_verified, because it was run on the game")
    t.eq(rec.stable, true, "  stable, which is what reproduced means to the gate")
    t.eq(rec.measured.damage, 2400, "  the measured damage, from the counted links")
    t.eq(rec.measured.hits, 2, "  and the hit count")
    t.eq(rec.route_id, EDGE, "  route_id is the pair, which is what the subject was")
    t.ok(rec.route_source:find("never authored as a route file"),
         "  and it says the pair is not a route document")
    t.eq(rec.provenance.game_patch, PATCH, "  provenance carries the patch")
    t.eq(rec.provenance.calibration_id, CAL, "  and the calibration")
    t.eq(rec.evidence.successful_runs, 2, "  the evidence carries the counts")
    t.eq(table.concat(rec.evidence.linked_gaps, ","), "22", "  and the gaps it linked at")
    t.eq(rec.evidence.window.from, 22, "  and the window ConfirmedEdge measured")
    t.eq(rec.evidence.damage_span.samples, 2, "  two links read the damage")
    t.eq(#rec.route.steps, 2, "  the route's steps travel with it")
    t.eq(rec.route.steps[2].action_id, 1206, "  with their action ids")
    t.eq(rec.route.steps[2].notation, "236236 + 中", "  and their notations")
    t.eq(rec.id, VC.id_for(evs[1]), "  the id names the subject and the cohort")
    t.ok(rec.id:find("@", 1, true) ~= nil, "  two cohorts cannot collide on it")
end

t.group("the record says which fields nobody measured")

do
    local evs = reproduced({ measured_damage = 2400 }, { measured_damage = 2400 })
    local rec = VC.build(evs)[1]
    local seen = {}
    for _, u in ipairs(rec.measured.unmeasured) do
        seen[u.field] = u.why
        t.ok(type(u.why) == "string" and u.why ~= "", "  " .. u.field .. " says why")
    end
    t.ok(seen.drive_spent ~= nil, "drive_spent is named as unmeasured, not omitted")
    t.ok(seen.knockdown_type ~= nil, "  so is knockdown_type")
    t.ok(seen.side_switch ~= nil, "  so is side_switch")
    t.ok(seen.difficulty ~= nil, "  so is difficulty")
    t.ok(seen.hits ~= nil, "  and hits, because these runs recorded no hit count")
    t.is_nil(rec.measured.drive_spent, "and no key is invented to hold them")
end

t.group("a measured hit count is not then listed as unmeasured")

do
    local evs = reproduced({ measured_damage = 2400, measured_hits = 3 },
                           { measured_damage = 2400, measured_hits = 3 })
    local rec = VC.build(evs)[1]
    local named = false
    for _, u in ipairs(rec.measured.unmeasured) do
        if u.field == "hits" then named = true end
    end
    t.eq(named, false, "hits was read, so it is not on the unmeasured list")
    t.eq(rec.measured.hits, 3, "  it is on the record")
end

-- --- no damage ---------------------------------------------------------------

t.group("a reproduced subject with no damage produces no record")

do
    local evs = reproduced()
    t.eq(evs[1].result, E.RESULT.REPRODUCED, "the policy still says reproduced")
    t.is_nil(evs[1].measured_summary.damage, "  and the evaluation carries no damage")

    local records, refused, counts = VC.build(evs)
    t.eq(#records, 0, "no record is produced")
    t.eq(#refused, 1, "it is refused instead of dropped")
    t.eq(refused[1].reason, VC.REASON.DAMAGE_NOT_MEASURED, "  with the reason")
    t.eq(refused[1].subject_id, EDGE, "  naming the subject")
    t.ok(refused[1].detail:find("RouteRun"), "  and what would record one")
    t.eq(counts.by_reason[VC.REASON.DAMAGE_NOT_MEASURED], 1, "  counted under that reason")
    t.eq(#VC.blocked_by_measurement(refused), 1, "  and it is a session-on-the-game blocker")
end

t.group("counted links that disagree about damage are refused, not averaged")

do
    local evs = reproduced({ measured_damage = 2400 }, { measured_damage = 2600 })
    local records, refused = VC.build(evs)
    t.eq(#records, 0, "no record")
    t.eq(refused[1].reason, VC.REASON.DAMAGE_DISAGREES, "  refused for the disagreement")
    t.eq(refused[1].damage.min, 2400, "  the low reading is named")
    t.eq(refused[1].damage.max, 2600, "  and the high one")
    t.ok(refused[1].detail:find("no trial produced"), "  and the mean is refused out loud")
    t.eq(#VC.blocked_by_measurement(refused), 1, "  it too is cleared by measuring again")
end

-- --- not reproduced ----------------------------------------------------------

t.group("observed_success is not published")

do
    local evs = evaluate({ run("link", 4) })
    t.eq(evs[1].result, E.RESULT.OBSERVED_SUCCESS, "one link at one delay is observed_success")
    local records, refused, counts = VC.build(evs)
    t.eq(#records, 0, "no record, even though it linked")
    t.eq(refused[1].reason, VC.REASON.NOT_REPRODUCED, "  refused as not reproduced")
    t.ok(refused[1].detail:find("observed_success"), "  and the detail names the result")
    t.eq(counts.by_result.observed_success, 1, "  the result is counted for the report")
    t.eq(#VC.blocked_by_measurement(refused), 0,
         "  measuring damage would not fix it: it needs another trial")
end

t.group("a subject with only failures is not published either")

do
    local evs = evaluate({ run("whiff", 30), run("whiff", 34) })
    t.eq(evs[1].result, E.RESULT.NO_SUCCESS_OBSERVED, "no_success_observed")
    local records, refused = VC.build(evs)
    t.eq(#records, 0, "no record")
    t.eq(refused[1].reason, VC.REASON.NOT_REPRODUCED, "  refused as not reproduced")
end

-- --- gauges ------------------------------------------------------------------

t.group("the gauges travel when the runs have them")

do
    local g = { drive_start = 6.0, drive_end = 4.5, super_start = 1000, super_end = 1800 }
    local evs = reproduced({ measured_damage = 2400, measured_gauges = g },
                           { measured_damage = 2400, measured_gauges = g })
    local rec = VC.build(evs)[1]
    t.ok(rec.measured.gauges ~= nil, "measured carries a gauges block")
    t.eq(rec.measured.gauges.drive_start.min, 6.0, "  the Drive bar at the first tick")
    t.eq(rec.measured.gauges.drive_end.max, 4.5, "  and at the last")
    t.eq(rec.measured.gauges.super_end.samples, 2, "  over both counted links")
    t.is_nil(rec.measured.drive_spent,
             "and nothing decides which part of the change was a spend")
end

t.group("no gauges is no gauges block, not zeroed bars")

do
    local evs = reproduced({ measured_damage = 2400 }, { measured_damage = 2400 })
    t.is_nil(VC.build(evs)[1].measured.gauges, "absent, not a block of zeroes")
end

-- --- the KnowledgeDb gate ----------------------------------------------------

local EXPORT = {
    character = "zangief", game_patch = PATCH, calibration_id = CAL,
    game_version = "sf6-2026-08", action_slugs = {},
}

local function export_opts(over)
    local o = {}
    for k, v in pairs(EXPORT) do o[k] = v end
    for k, v in pairs(over or {}) do o[k] = v end
    return o
end

t.group("with no slug table, the gate refuses and names every move it wants")

do
    local evs = reproduced({ measured_damage = 2400 }, { measured_damage = 2400 })
    local records = VC.build(evs)
    local out = KDB.export(records, export_opts())
    t.eq(out.counts.exported, 0, "nothing crosses")
    t.eq(out.counts.by_reason[KDB.REASON.MOVE_SLUG_MISSING], 1, "  for want of a moves.yaml slug")
    t.eq(#out.missing_moves, 2, "  both moves are named")
    t.eq(out.missing_moves[1].action_id, 617, "  by action id")
    t.eq(out.missing_moves[1].notation, "2 + 弱", "  with the notation to add them under")
    t.eq(out.missing_moves[1].display, "2 + L", "  and a rendering with no catalog token left in it")
    t.eq(#out.missing_moves[2].wanted_by, 1, "  and how many combos each one blocks")
end

t.group("with a slug table, the same record crosses")

do
    local evs = reproduced({ measured_damage = 2400 }, { measured_damage = 2400 })
    local records = VC.build(evs)
    local out = KDB.export(records, export_opts({
        action_slugs = { [617] = "crouching-lp", [1206] = "screw-piledriver" },
    }))
    t.eq(out.counts.exported, 1, "one combo crosses once the slugs exist")
    t.eq(out.counts.rejected, 0, "  and nothing is rejected")
    t.eq(out.combos[1].outcomes.damage, 2400, "  carrying the measured damage")
    t.eq(out.combos[1].control_scheme, "modern", "  the scheme it was measured under")
    t.eq(out.combos[1].input_style, "manual", "  the style derived from its steps")
    t.eq(#out.combos[1].steps, 2, "  and its steps")
    t.ok(out.combos[1].notes:find(CAL, 1, true) ~= nil,
         "  with the calibration in the notes, so the figure is traceable")
end

t.group("a record from another cohort is turned away with its own reason")

do
    local evs = reproduced({ measured_damage = 2400 }, { measured_damage = 2400 })
    local records = VC.build(evs)
    local out = KDB.export(records, export_opts({ calibration_id = "CAL-OTHER" }))
    t.eq(out.counts.exported, 0, "nothing crosses")
    t.eq(out.counts.by_reason[KDB.REASON.CALIBRATION_MISMATCH], 1,
         "  because it was measured under a different calibration")

    out = KDB.export(records, export_opts({ game_patch = "99999999" }))
    t.eq(out.counts.by_reason[KDB.REASON.PATCH_MISMATCH], 1, "  and the same for the patch")
end

t.group("the export refuses to judge anything without its context")

do
    local evs = reproduced({ measured_damage = 2400 }, { measured_damage = 2400 })
    local records = VC.build(evs)
    -- Everything but the version code the target's combos.yaml has to carry.
    local opts = export_opts()
    opts.game_version = nil
    local out, why = KDB.export(records, opts)
    t.is_nil(out, "no result at all")
    t.eq(why.reason, KDB.REASON.CONTEXT, "  the context is incomplete")
    local named = false
    for _, p in ipairs(why.problems) do
        if p.field == "game_version" then named = true end
    end
    t.ok(named, "  and it names the field that is missing")
end

-- --- the whole set -----------------------------------------------------------

t.group("every evaluation given produces exactly one of a record and a refusal")

do
    local evs = {}
    for _, ev in ipairs(reproduced({ measured_damage = 2400 }, { measured_damage = 2400 })) do
        evs[#evs + 1] = ev
    end
    for _, ev in ipairs(evaluate({ run("link", 4) })) do evs[#evs + 1] = ev end
    for _, ev in ipairs(evaluate({ run("wrong_move", 8) })) do evs[#evs + 1] = ev end

    local records, refused, counts = VC.build(evs)
    t.eq(counts.evaluations, #evs, "every evaluation was looked at")
    t.eq(#records + #refused, #evs, "  and none was silently dropped")
    t.eq(counts.by_result.pending, 1, "  the unanswered subject is counted as pending")
end

return t.finish()
