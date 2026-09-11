-- Unit tests for func/ComboExplorer/core/Provenance.lua
--
-- The point of these is not that the module works, it is that the module
-- REFUSES. Every assertion below is really asking: can something read an
-- unverified value by accident, and can injection start before the values it
-- depends on have been measured on a real machine?

local t = require("tests.lua.harness")
local P = require("func/ComboExplorer/core/Provenance")

-- --- everything starts unknown ----------------------------------------------

t.group("initial state")

local reg = P.new()
local n = reg:summary()

t.eq(n.verified, 0, "nothing is verified on a fresh register")
t.eq(n.refuted, 0, "nothing is refuted either")
t.ok(n.total >= 9, "all nine unknowns are registered (got " .. n.total .. ")")
t.eq(n.unverified, n.total, "every entry starts unverified")

-- The nine the project owner listed explicitly.
for _, key in ipairs({
    "input_hook_calls_per_frame",
    "tick_equals_frame",
    "hitstop_advances_tick",
    "combo_damage_readable",
    "modern_button_bits",
    "rl_dir_polarity",
    "action_id_canonical",
    "reset_settle_ticks",
    "frame_meter_semantics",
}) do
    t.ok(reg:get(key) ~= nil, "registered: " .. key)
end

-- --- unverified values cannot be read by accident ---------------------------

t.group("value() withholds guesses")

local v, status = reg:value("modern_button_bits")
t.is_nil(v, "value() returns nil while unverified")
t.eq(status, P.STATUS.UNVERIFIED, "and says why")

local guess, gstatus = reg:provisional("modern_button_bits")
t.ok(type(guess) == "table", "provisional() hands over the guess")
t.eq(guess.L, 0x10, "the guess is the one from the display code")
t.eq(gstatus, P.STATUS.UNVERIFIED, "provisional() forces the status through the caller's hands")

t.is_nil(reg:value("nope"), "unknown key returns nil")

-- Mutating what comes back must not corrupt the register: a caller that pokes
-- at a returned table would otherwise silently rewrite the provenance.
guess.L = 0x999
local again = reg:provisional("modern_button_bits")
t.eq(again.L, 0x10, "returned values are copies, not references")

-- --- capabilities are blocked until measured --------------------------------

t.group("capability gating")

local function contains(list, want)
    for _, x in ipairs(list) do if x == want then return true end end
    return false
end

local can_inject, blocked = reg:can(P.CAPABILITY.INJECTION)
t.eq(can_inject, false, "injection is blocked on a fresh register")
t.eq(#blocked, 3, "injection is gated by exactly the three input-mapping values")
t.ok(contains(blocked, "modern_button_bits"), "button bits block injection")
t.ok(contains(blocked, "direction_bits"), "direction bits block injection")
t.ok(contains(blocked, "rl_dir_polarity"), "rl_dir polarity blocks injection")
t.ok(not contains(blocked, "input_hook_calls_per_frame"),
     "the tick rate does NOT gate injection - pressing a button needs no clock")

t.eq(reg:can(P.CAPABILITY.DAMAGE), false, "damage is blocked")
t.eq(reg:can(P.CAPABILITY.TIMING), false, "timing is blocked")
t.eq(reg:can(P.CAPABILITY.STAGE_RESET), false, "stage reset is blocked")

-- PROBING is the composite: press the right button, at a known delay, from a
-- reproducible state. Its blockers must be the union of what it requires.
local can_probe, probe_blocked = reg:can(P.CAPABILITY.PROBING)
t.eq(can_probe, false, "probing is blocked")
t.ok(contains(probe_blocked, "modern_button_bits"), "probing inherits injection's gates")
t.ok(contains(probe_blocked, "input_hook_calls_per_frame"), "probing inherits timing's gates")
t.ok(contains(probe_blocked, "tick_equals_frame"), "probing needs a known delay unit")
t.ok(contains(probe_blocked, "reset_settle_ticks"), "probing inherits stage-reset's gates")
t.ok(#probe_blocked > #blocked, "probing is strictly harder to satisfy than injection")

local why = reg:explain(P.CAPABILITY.INJECTION)
t.ok(why:find("BLOCKED", 1, true) ~= nil, "explain() says it is blocked")
t.ok(why:find("calibration_button_bits", 1, true) ~= nil,
     "explain() names the measurement that would unblock it")

-- --- calibration promotes entries -------------------------------------------

t.group("apply_calibration")

local applied, rejected = reg:apply_calibration({
    calibration_id = "cal-2026-09-10-a",
    game_patch = "2026-08-03",
    values = {
        modern_button_bits = {
            status = P.STATUS.VERIFIED,
            value = { L = 0x10, M = 0x80, H = 0x100, SP = 0x20, AUTO = 0x200,
                      PARRY = 0x40, DI = 0x1000, THROW = 0x2000 },
        },
        direction_bits = {
            status = P.STATUS.VERIFIED,
            value = { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 },
        },
        rl_dir_polarity = { status = P.STATUS.VERIFIED, value = "mirror_when_falsy" },
    },
})

t.eq(#applied, 3, "three entries applied")
t.eq(#rejected, 0, "nothing rejected")
t.eq(reg.calibration_id, "cal-2026-09-10-a", "calibration id recorded")
t.eq(reg.game_patch, "2026-08-03", "game patch recorded")

local bits = reg:value("modern_button_bits")
t.ok(bits ~= nil, "value() now returns the verified value")
t.eq(bits.SP, 0x20, "and it is the measured one")
t.eq(reg:get("modern_button_bits").verified_by, "cal-2026-09-10-a", "provenance records who verified it")

t.eq(reg:can(P.CAPABILITY.INJECTION), true, "injection unblocks once its three gates are verified")
t.eq(reg:can(P.CAPABILITY.DAMAGE), false, "but damage is still blocked - different gate")

-- This is the shape of the real workflow: the smoke test becomes possible as
-- soon as the button map is measured, while the brute-force sweep still waits
-- on the clock and the reset.
t.eq(reg:can(P.CAPABILITY.PROBING), false, "probing stays blocked - timing and reset are still unknown")

reg:apply_calibration({
    calibration_id = "cal-2026-09-10-b",
    values = {
        input_hook_calls_per_frame = { status = P.STATUS.VERIFIED, value = 1 },
        tick_equals_frame          = { status = P.STATUS.VERIFIED, value = true },
        hitstop_advances_tick      = { status = P.STATUS.VERIFIED, value = false },
        reset_settle_ticks         = { status = P.STATUS.VERIFIED, value = 31 },
    },
})
t.eq(reg:can(P.CAPABILITY.TIMING), true, "timing unblocks")
t.eq(reg:can(P.CAPABILITY.STAGE_RESET), true, "stage reset unblocks")
t.eq(reg:can(P.CAPABILITY.PROBING), true, "and only then does probing unblock")

-- A measurement that contradicts the guess is still knowledge, and must be
-- usable. Recording it as "refuted" rather than "verified" keeps the fact that
-- the guess was wrong, which is worth knowing when the next character is added.
t.group("refuted is a measurement, not a failure")

local reg2 = P.new()
reg2:apply_calibration({
    calibration_id = "cal-b",
    values = {
        modern_button_bits = {
            status = P.STATUS.REFUTED,
            value = { L = 0x10, M = 0x20, H = 0x40, SP = 0x80, AUTO = 0x100,
                      PARRY = 0x200, DI = 0x1000, THROW = 0x2000 },
            note = "display-code table was wrong: M and SP are swapped",
        },
    },
})
local e2 = reg2:get("modern_button_bits")
t.eq(e2.status, P.STATUS.REFUTED, "status is refuted")
t.eq(e2.value.M, 0x20, "the measured value replaced the guess")
t.eq(e2.measurement_note, "display-code table was wrong: M and SP are swapped", "the note survives")
-- Refuted is a measurement, so it satisfies value() and it opens the gate. The
-- alternative was tried and is worse: the first real dataset refuted
-- hitstop_advances_tick and reset_settle_ticks, and holding those back would
-- have shut TIMING and STAGE_RESET because the measurement disagreed with a
-- guess nobody had ever checked.
t.eq(reg2:value("modern_button_bits").M, 0x20,
     "a refuted value is a measured value, and value() hands it back")
t.eq(reg2:is_verified("modern_button_bits"), false,
     "is_verified still answers the narrower question: did the guess hold")
t.eq(reg2:is_measured("modern_button_bits"), true, "is_measured answers the wider one")
-- INJECTION is gated by three entries and only one was supplied here, so the
-- capability is still shut. What matters is WHY: the refuted entry is no longer
-- one of the reasons.
local _, still_blocking = reg2:can(P.CAPABILITY.INJECTION)
local names = table.concat(still_blocking, ",")
t.ok(not names:find("modern_button_bits"),
     "the refuted entry stops being a blocker - it was measured, it just was not "
     .. "what we thought (still blocked by: " .. names .. ")")
t.eq(#still_blocking, 2, "leaving only the two nobody has measured")

-- --- malformed calibration is visible, not half-absorbed --------------------

t.group("calibration rejection")

local reg3 = P.new()
local ap, rej = reg3:apply_calibration({
    calibration_id = "cal-c",
    values = {
        not_a_real_key   = { status = P.STATUS.VERIFIED, value = 1 },
        modern_button_bits = { status = "probably",       value = {} },
        direction_bits   = { status = P.STATUS.VERIFIED },
        rl_dir_polarity  = "mirror_when_falsy",
    },
})
t.eq(#ap, 0, "nothing malformed is applied")
t.eq(#rej, 4, "every malformed entry is reported")

local reasons = {}
for _, r in ipairs(rej) do reasons[r.key] = r.reason end
t.eq(reasons.not_a_real_key, "unknown key", "unknown key rejected")
t.eq(reasons.modern_button_bits, "status must be a measurement: verified, refuted or partial", "bad status rejected")
t.eq(reasons.direction_bits, "no value", "missing value rejected")
t.eq(reasons.rl_dir_polarity, "entry is not a table", "non-table rejected")

t.eq(reg3:can(P.CAPABILITY.INJECTION), false, "a malformed calibration unblocks nothing")

local _, rej2 = P.new():apply_calibration("not a table")
t.eq(#rej2, 1, "a non-table profile is rejected outright")

-- --- invalidation ------------------------------------------------------------

t.group("invalidate")

-- An action id measured on one patch is not evidence about another, so a patch
-- change has to take the whole register back to unknown.
reg:invalidate("game patch changed")
t.eq(reg:summary().verified, 0, "invalidate clears every verification")
t.eq(reg:can(P.CAPABILITY.INJECTION), false, "and re-blocks injection")
t.eq(reg:get("modern_button_bits").invalidated_reason, "game patch changed", "the reason is kept")
t.is_nil(reg.calibration_id, "the calibration id is dropped")

-- --- snapshot ----------------------------------------------------------------

t.group("snapshot")

local snap = P.new():snapshot()
t.ok(snap.entries.modern_button_bits ~= nil, "entries are present")
t.eq(snap.entries.modern_button_bits.status, P.STATUS.UNVERIFIED, "with status")
t.ok(snap.capabilities.injection ~= nil, "capabilities are summarised")
t.eq(snap.capabilities.injection.available, false, "injection unavailable")
t.ok(#snap.capabilities.injection.blocked_by >= 3, "with its blockers listed")

-- Two registers must not share state through the defaults table.
local a, b = P.new(), P.new()
a:apply_calibration({ calibration_id = "x", values = {
    rl_dir_polarity = { status = P.STATUS.VERIFIED, value = "mirror_when_truthy" } } })
t.eq(b:get("rl_dir_polarity").status, P.STATUS.UNVERIFIED, "registers are independent")
t.eq(P.DEFAULTS.rl_dir_polarity.status, P.STATUS.UNVERIFIED, "and the defaults are not mutated")

return t.finish()
