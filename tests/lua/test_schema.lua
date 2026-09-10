-- Unit tests for func/ComboExplorer/core/Schema.lua
--
-- Every assertion here is really one question: can something that has never
-- been run on Street Fighter 6 end up written to a file as `verified`?
--
-- That is the failure the whole project is arranged against. The offline
-- pipeline will produce thousands of candidates, none of them facts, and once a
-- theoretical row is written as verified nothing downstream can tell the
-- difference.

local t = require("tests.lua.harness")
local S = require("func/ComboExplorer/core/Schema")

local function edge(over)
    local e = S.new(S.KIND.EDGE, {
        id = "e1",
        from = { action_id = 604, input_method = "manual", notation = "M" },
        to   = { action_id = 621, input_method = "manual", notation = "2 + M" },
        reasons = { "frame_link" },
        requires_runtime_validation = { "pushback_range" },
        provenance = { game_patch = "2026-08-03" },
    })
    for k, v in pairs(over or {}) do e[k] = v end
    return e
end

-- --- offline records start honest -------------------------------------------

t.group("what S.new produces")

local e = edge()
t.eq(e.schema, S.KIND.EDGE, "carries its schema tag")
t.eq(e.status, "theoretical", "starts theoretical")
t.eq(e.runtime_verified, false, "and explicitly not runtime-verified")
t.ok(S.validate(S.KIND.EDGE, e), "and validates")

-- --- the rule ----------------------------------------------------------------

t.group("verified requires evidence")

local ok, problems = S.validate(S.KIND.EDGE, edge({ status = "verified" }))
t.eq(ok, false, "a verified edge with nothing behind it is refused")

local fields = {}
for _, p in ipairs(problems) do fields[p.field] = p.problem end
t.ok(fields.runtime_verified ~= nil, "it must claim runtime_verified")
t.ok(fields.evidence ~= nil, "it must carry evidence")
t.ok(fields["provenance.calibration_id"] ~= nil, "and name the calibration it ran under")

-- The patch is a separate complaint, so it needs a record that is missing it -
-- the edge above already carries one.
local _, no_patch = S.validate(S.KIND.EDGE, edge({
    status = "verified", runtime_verified = true, evidence = {},
    provenance = { calibration_id = "cal-1" },
}))
local patch_fields = {}
for _, p in ipairs(no_patch) do patch_fields[p.field] = p.problem end
t.ok(patch_fields["provenance.game_patch"] ~= nil, "and the patch it was measured on")

-- With all of it, it passes.
ok = S.validate(S.KIND.EDGE, edge({
    status = "verified",
    runtime_verified = true,
    evidence = { attempts = 3, successes = 3 },
    provenance = { game_patch = "2026-08-03", calibration_id = "cal-1" },
}))
t.ok(ok, "a verified edge with real evidence is accepted")

-- Rejection is a claim about the game too. "We tried it and it failed" and "we
-- never tried it" are different facts, and only the first should stop anyone
-- re-testing.
ok, problems = S.validate(S.KIND.EDGE, edge({ status = "rejected" }))
t.eq(ok, false, "a rejected edge needs evidence just as much")

t.group("theoretical cannot claim otherwise")

ok, problems = S.validate(S.KIND.EDGE, edge({ runtime_verified = true }))
t.eq(ok, false, "a theoretical edge claiming runtime_verified is refused")
fields = {}
for _, p in ipairs(problems) do fields[p.field] = p.problem end
t.ok(fields.runtime_verified ~= nil, "and that is the complaint")

ok = S.validate(S.KIND.EDGE, edge({ status = "made_up" }))
t.eq(ok, false, "an invented status is refused")

-- --- transitions -------------------------------------------------------------

t.group("transitions")

t.ok(S.can_transition("theoretical", "runtime_pending"), "theoretical can be queued")
t.eq(S.can_transition("theoretical", "verified"), false,
     "but cannot jump straight to verified - something has to run it")
t.ok(S.can_transition("runtime_pending", "verified"), "a queued trial can succeed")
t.ok(S.can_transition("runtime_pending", "rejected"), "or fail")
t.ok(S.can_transition("verified", "runtime_pending"), "and a verified edge can be re-tested after a patch")

e = edge()
t.ok(S.transition(e, "runtime_pending"), "queueing works")
t.eq(e.status, "runtime_pending", "and the status moves")
t.eq(e.runtime_verified, false, "queued is still not verified")

local moved, why = S.transition(e, "verified")
t.eq(moved, false, "promoting without evidence is refused")
t.ok(why:find("evidence", 1, true) ~= nil, "and says what is missing")
t.eq(e.status, "runtime_pending", "and the record is unchanged")

t.ok(S.transition(e, "verified", { attempts = 3, successes = 3 }), "with evidence it promotes")
t.eq(e.status, "verified", "status moved")
t.eq(e.runtime_verified, true, "and the flag was set by the transition, not by hand")
t.ok(e.evidence ~= nil, "the evidence is attached to the record")

t.eq(S.transition(edge(), "verified", { x = 1 }), false,
     "theoretical still cannot jump the queue even with evidence in hand")

-- --- edges have to justify themselves ---------------------------------------

t.group("a candidate says why")

ok = S.validate(S.KIND.EDGE, edge({ reasons = {} }))
t.eq(ok, false, "an edge with no reason is not a candidate")

-- There is no such thing as an edge a frame table fully settles: spacing alone
-- can break any of them, and the frame data literally records pushback as null.
ok, problems = S.validate(S.KIND.EDGE, edge({ requires_runtime_validation = {} }))
t.eq(ok, false, "an edge claiming nothing needs checking is refused")
fields = {}
for _, p in ipairs(problems) do fields[p.field] = p.problem end
t.ok(fields.requires_runtime_validation:find("fully decidable", 1, true) ~= nil,
     "and the reason says why that cannot be true")

t.ok(#S.ALWAYS_UNKNOWN >= 3, "there is a standing list of what is never decidable offline")

-- --- offline scores must not look measured ----------------------------------

t.group("predictions never wear a measurement's name")

local function route(over)
    local r = S.new(S.KIND.ROUTE, {
        id = "r1",
        steps = { { action_id = 604 }, { action_id = 621 } },
        provenance = { game_patch = "2026-08-03" },
    })
    for k, v in pairs(over or {}) do r[k] = v end
    return r
end

t.ok(S.validate(S.KIND.ROUTE, route()), "a plain route validates")
t.ok(S.validate(S.KIND.ROUTE, route({ offline_score = { predicted_damage = 2100 } })),
     "a predicted figure is fine")

ok, problems = S.validate(S.KIND.ROUTE, route({ offline_score = { damage = 2100 } }))
t.eq(ok, false, "a bare `damage` in an offline score is refused")
ok = S.validate(S.KIND.ROUTE, route({ offline_score = { execution_leniency_frames = 3 } }))
t.eq(ok, false, "so is a leniency window nobody measured")

ok = S.validate(S.KIND.ROUTE, route({ steps = { { action_id = 604 } } }))
t.eq(ok, false, "one step is not a route")

-- --- moves -------------------------------------------------------------------

t.group("moves")

local function move(over)
    local m = S.new(S.KIND.MOVE, {
        action_id = 621, input_method = "manual", notation = "2 + M",
        standalone = true, canonical_status = "unresolved",
    })
    for k, v in pairs(over or {}) do m[k] = v end
    return m
end

t.ok(S.validate(S.KIND.MOVE, move()), "a standalone move validates")
t.eq(S.validate(S.KIND.MOVE, move({ input_method = "auto" })), false, "an unknown input method is refused")
t.eq(S.validate(S.KIND.MOVE, move({ canonical_status = "obviously_617" })), false,
     "and an invented canonical status")
t.eq(S.validate(S.KIND.MOVE, move({ standalone = false })), false,
     "a non-standalone move must say why it is not")
t.ok(S.validate(S.KIND.MOVE, move({ standalone = false, exclusion = "followup" })),
     "with a reason it validates")

-- --- confirmed edges and combos ----------------------------------------------

t.group("runtime records")

local confirmed = S.new(S.KIND.CONFIRMED, {
    id = "c1", edge_id = "e1", attempts = 3, successes = 3, stable = true,
    provenance = { game_patch = "2026-08-03", calibration_id = "cal-1" },
})
S.transition(confirmed, "runtime_pending")
t.ok(S.transition(confirmed, "verified", { successes = 3 }), "a confirmed edge promotes with evidence")
t.ok(S.validate(S.KIND.CONFIRMED, confirmed), "and validates")

confirmed.stable = false
ok, problems = S.validate(S.KIND.CONFIRMED, confirmed)
t.eq(ok, false, "a verified edge that never reproduced is refused")
confirmed.unstable_ok = true
t.ok(S.validate(S.KIND.CONFIRMED, confirmed), "unless it says so knowingly")

local combo = S.new(S.KIND.COMBO, {
    id = "v1", route_id = "r1", measured = { damage = 2780 },
    provenance = { game_patch = "2026-08-03", calibration_id = "cal-1" },
})
S.transition(combo, "runtime_pending")
S.transition(combo, "verified", { trials = 3 })
t.ok(S.validate(S.KIND.COMBO, combo), "a verified combo with a measured damage validates")
combo.measured = {}
t.eq(S.validate(S.KIND.COMBO, combo), false, "without a measured damage it does not")

-- --- calibration and diagnostics are records, not claims ---------------------

t.group("calibration and diagnostics")

local cal = { schema = S.KIND.CALIBRATION, calibration_id = "cal-1",
              game_patch = "2026-08-03", values = {} }
t.ok(S.validate(S.KIND.CALIBRATION, cal), "a calibration needs no status")

local diag = { schema = S.KIND.DIAGNOSTICS, probe = "A", header = {}, body = {} }
t.ok(S.validate(S.KIND.DIAGNOSTICS, diag), "nor does a diagnostics report")

-- --- provenance --------------------------------------------------------------

t.group("provenance")

local prov = S.provenance({
    game_patch = "2026-08-03",
    command_display = { character = "Zangief", ac_sha256 = "abc", bcm_sha256 = "def" },
    frame_data = { source = "sf6-sensei", commit = "a64f2ac", license = "CC-BY-SA-4.0" },
})
t.eq(prov.command_display.ac_sha256, "abc", "the AC checksum travels with the data")
t.eq(prov.frame_data.license, "CC-BY-SA-4.0", "so does the frame data licence")
t.is_nil(S.provenance({}).frame_data, "an absent source is absent, not an empty shell")

-- --- degenerate input --------------------------------------------------------

t.group("degenerate input")

t.eq(S.validate(S.KIND.EDGE, nil), false, "nil is refused")
t.eq(S.validate(S.KIND.EDGE, { schema = "something.else" }), false, "the wrong schema is refused")
t.eq(S.validate("ce.nonexistent.v1", { schema = "ce.nonexistent.v1" }), false,
     "an unknown kind has no validator and is refused")

-- --- re-testing after a patch ------------------------------------------------

t.group("leaving a runtime status")

-- The vocabulary allows verified -> runtime_pending, which is how a record gets
-- re-tested after a patch. It has to actually work: if the record keeps
-- runtime_verified = true and last patch's evidence, validate() refuses it, and
-- the re-test cannot be written down at all.
local requeued = S.new(S.KIND.EDGE, {
    id = "a->b", from = { action_id = 1 }, to = { action_id = 2 },
    reasons = { "frame_link" },
    requires_runtime_validation = { "actual_input_timing" },
    provenance = { game_patch = "old", calibration_id = "cal-1" },
})
t.ok(S.transition(requeued, S.STATUS.RUNTIME_PENDING), "queued")
t.ok(S.transition(requeued, S.STATUS.VERIFIED, { attempts = 3, successes = 3 }), "verified")
t.eq(requeued.runtime_verified, true, "and it says it was run")

t.ok(S.transition(requeued, S.STATUS.RUNTIME_PENDING), "the patch re-test transition is allowed")
t.eq(requeued.status, "runtime_pending", "and takes effect")
t.eq(requeued.runtime_verified, false, "the record no longer claims to have been run")
t.is_nil(requeued.evidence, "and the stale evidence is not left attached")
t.ok(S.validate(S.KIND.EDGE, requeued), "so the re-queued record validates, and can be written")

-- The old measurement is not thrown away; it is filed as history, under a name
-- that cannot be mistaken for a current claim.
t.ok(requeued.superseded_evidence ~= nil, "the previous evidence is kept as history")
t.eq(requeued.superseded_status, "verified", "with the status it was evidence for")

local rerejected = S.new(S.KIND.EDGE, {
    id = "c->d", from = { action_id = 3 }, to = { action_id = 4 },
    reasons = { "frame_link" },
    requires_runtime_validation = { "actual_input_timing" },
    provenance = { game_patch = "old", calibration_id = "cal-1" },
})
S.transition(rerejected, S.STATUS.RUNTIME_PENDING)
S.transition(rerejected, S.STATUS.REJECTED, { attempts = 3, successes = 0 })
t.ok(S.transition(rerejected, S.STATUS.RUNTIME_PENDING), "a rejected record re-queues too")
t.eq(rerejected.runtime_verified, false, "and stops claiming a runtime answer")
t.ok(S.validate(S.KIND.EDGE, rerejected), "and validates")

return t.finish()
