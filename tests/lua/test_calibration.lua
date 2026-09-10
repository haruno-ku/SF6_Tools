-- Unit tests for func/ComboExplorer/core/Calibration.lua
--
-- This module is the only thing that can flip a Provenance entry away from
-- unverified, so its failure mode is the worst one available: a calibration
-- that reports success it did not measure opens the injection gate, and every
-- trial after that is recorded as fact. Most of what follows is therefore
-- about REFUSING - what the module must decline to conclude, and why.

local t = require("tests.lua.harness")
local Calibration = require("func/ComboExplorer/core/Calibration")
local Provenance  = require("func/ComboExplorer/core/Provenance")
local Catalog     = require("func/ComboExplorer/core/Catalog")

local RAW = dofile("tests/lua/fixtures/zangief_catalog.lua")

local function fresh_catalog() return (Catalog.build(RAW)) end

local IDENTITY = {
    calibration_id = "test-cal", game_patch = "2026-08-03",
    ac_sha256 = "aaaa", bcm_sha256 = "bbbb", character = "Zangief",
}

-- =========================================================
t.group("from_probes - the clock")

do
    local b = {
        finding = { conclusive = true, calls_per_frame = 1, frames = 76565,
                    reason = "every one of 76565 usable frames saw exactly 1 call(s)" },
        hitstop = { conclusive = true, calls_per_frame_in_hitstop = 1.0 },
        frames = { with_hitstop = 475 },
    }
    local values, notes = Calibration.from_probes({ probe_b = b })

    t.eq(values.input_hook_calls_per_frame.status, "verified",
         "one call per frame matches the guess, so the guess is verified")
    t.eq(values.input_hook_calls_per_frame.value, 1, "and the value carries through")

    t.eq(values.tick_equals_frame.status, "verified",
         "the tick mapping had no guess to be wrong about")
    t.eq(values.tick_equals_frame.value.ticks_per_frame, 1,
         "recorded as a ratio, not a boolean - a later delay has to be convertible")

    -- The provisional value is false, taken from an upstream comment. The
    -- measurement says otherwise, and that is what refuted is for.
    t.eq(values.hitstop_advances_tick.status, "refuted",
         "the tick DOES advance during hitstop, so the guess was wrong")
    t.eq(values.hitstop_advances_tick.value, true, "and the measured value replaces it")

    -- Probe A and C were not supplied, so their entries are named as missing
    -- rather than quietly absent.
    t.eq(#notes, 2, "the two entries the other probes would settle are listed as missing")
    t.eq(notes[1].key, "combo_damage_readable", "probe A's entry")
    t.eq(notes[2].key, "reset_settle_ticks", "and probe C's")
end

do
    -- A clock sample with no hits in it says nothing about hitstop, and must
    -- not be read as "it does not advance".
    local b = {
        finding = { conclusive = true, calls_per_frame = 1, frames = 9000, reason = "ok" },
        hitstop = { conclusive = false, calls_per_frame_in_hitstop = 0 },
        frames = { with_hitstop = 0 },
    }
    local values, notes = Calibration.from_probes({ probe_b = b })
    t.is_nil(values.hitstop_advances_tick, "no hitstop sampled, so no verdict on hitstop")
    t.ok(values.input_hook_calls_per_frame ~= nil, "the rest of the clock still settles")

    local found = false
    for _, n in ipairs(notes) do
        if n.key == "hitstop_advances_tick" then found = true end
    end
    t.ok(found, "and the reason it was skipped is reported")
end

do
    local b = { finding = { conclusive = false, reason = "only 29 usable frames" } }
    local values = Calibration.from_probes({ probe_b = b })
    t.is_nil(values.input_hook_calls_per_frame, "an inconclusive probe settles nothing")
    t.is_nil(values.tick_equals_frame, "including the mapping")
end

-- =========================================================
t.group("from_probes - damage")

do
    local a = {
        sufficient = true, hp_arm_usable = true,
        carrying_side = "attacker", recommended_source = "both",
        counts = { agreed = 15, comparable = 18, nonzero = 20, total = 20 },
        verdict = "mComboDamage and the HP delta disagree on 3 of 18 comparable samples",
    }
    local values = Calibration.from_probes({ probe_a = a })
    t.eq(values.combo_damage_readable.status, "verified", "damage had no guess, so it verifies")
    t.eq(values.combo_damage_readable.value.readable, true, "the field read non-zero")
    t.eq(values.combo_damage_readable.value.side, "attacker", "and it says which side carries it")
    t.eq(values.combo_damage_readable.value.agreed, 15,
         "the disagreement count travels with the value, not just in prose")
end

do
    -- The dummy was on infinite health or a recovery timer: the field was never
    -- cross-checked against anything, so "it read a number" is not a result.
    local a = { sufficient = true, hp_arm_usable = false,
                counts = { nonzero = 20 }, verdict = "HP ARM INVALID" }
    local values, notes = Calibration.from_probes({ probe_a = a })
    t.is_nil(values.combo_damage_readable, "no HP arm means no verdict on damage")
    t.eq(notes[1].key, "combo_damage_readable", "and it is named in the notes")
end

-- =========================================================
t.group("from_probes - reset cost")

do
    local c = { sufficient = true, suggested_settle_ticks = 9,
                verdict = "a reset settles in 7-9 ticks (median 7)" }
    local values = Calibration.from_probes({ probe_c = c })
    -- The provisional is 25, arrived at by adding two of upstream's numbers.
    t.eq(values.reset_settle_ticks.status, "refuted", "25 was a bad guess")
    t.eq(values.reset_settle_ticks.value, 9, "the measured maximum replaces it")
end

do
    local c = { sufficient = false, verdict = "no resets observed" }
    local values = Calibration.from_probes({ probe_c = c })
    t.is_nil(values.reset_settle_ticks, "too few resets settles nothing")
end

do
    local values, notes = Calibration.from_probes({})
    t.eq(next(values), nil, "no reports, no values")
    t.eq(#notes, 5, "and every entry the probes would have settled is listed as missing")
end

-- =========================================================
t.group("the profile the register accepts")

do
    local b = {
        finding = { conclusive = true, calls_per_frame = 1, frames = 76565, reason = "ok" },
        hitstop = { conclusive = true, calls_per_frame_in_hitstop = 1.0 },
        frames = { with_hitstop = 475 },
    }
    local c = { sufficient = true, suggested_settle_ticks = 9, verdict = "ok" }
    local values = Calibration.from_probes({ probe_b = b, probe_c = c })

    local doc, err = Calibration.document(IDENTITY, { values })
    t.ok(doc ~= nil, "a document is produced: " .. tostring(err))
    t.eq(doc.schema, "ce.calibration.v1", "carrying its schema")
    t.eq(doc.game_patch, "2026-08-03", "and the build it was taken on")

    -- The point of the whole module: this has to move the register.
    local reg = Provenance.new()
    local before = Provenance.can(reg, "stage_reset")
    t.eq(before, false, "stage_reset starts blocked")

    local applied, rejected = Provenance.apply_calibration(reg, doc)
    t.eq(#rejected, 0, "the register rejects nothing in it")
    t.ok(#applied >= 4, "and takes every value")
    t.eq(Provenance.can(reg, "injection"), false,
         "injection stays shut - no button bit has been measured")

    -- Both of these measurements contradicted their guess, so they land as
    -- REFUTED - which counts. A capability whose gates were measured opens
    -- whether or not the guess survived; see is_measured in Provenance.lua.
    t.eq(Provenance.get(reg, "reset_settle_ticks").value, 9,
         "the measured reset cost replaced the guess in the register")
    t.eq(Provenance.get(reg, "reset_settle_ticks").status, "refuted", "as a refutation")
    t.eq(Provenance.can(reg, "stage_reset"), true,
         "and stage_reset opens on it - a refuted measurement is still a measurement")
    t.eq(Provenance.can(reg, "timing"), true,
         "same for timing, whose hitstop entry was also refuted")
end

do
    local doc, err = Calibration.document({ calibration_id = "x" }, { { a = 1 } })
    t.is_nil(doc, "a profile with no build identity is refused")
    t.ok(tostring(err):find("game_patch"), "and says which fields are missing: " .. tostring(err))
end

do
    local doc, err = Calibration.document(IDENTITY, {})
    t.is_nil(doc, "a profile with no measured values is not a calibration")
    t.ok(err ~= nil, "and says so")
end

-- =========================================================
t.group("the sweep plan")

local function new_session()
    local s, err = Calibration.new({ catalog = fresh_catalog() })
    t.ok(s ~= nil, "a session builds off a real catalog: " .. tostring(err))
    return s
end

do
    local s = new_session()
    local steps = Calibration.plan(s)

    t.eq(steps[1].phase, "neutral",
         "the first step asks what standing still looks like, rather than assuming it")
    t.eq(steps[1].mask, 0, "by writing nothing")

    local by_phase = {}
    for _, st in ipairs(steps) do by_phase[st.phase] = (by_phase[st.phase] or 0) + 1 end
    t.eq(by_phase.button_bits, 8, "one step per distinct bit in the provisional map")
    t.eq(by_phase.direction, 4, "LEFT and RIGHT, on both sides")

    -- Every step that writes from a guess has to say which guess.
    local untested = 0
    for _, st in ipairs(steps) do
        if st.phase ~= "neutral" and #(st.tests or {}) == 0 then untested = untested + 1 end
    end
    t.eq(untested, 0, "every step names the provisional entry it is exercising")

    local ambiguous = #Catalog.ambiguous_groups(s.catalog)
    t.ok((by_phase.action_sweep or 0) > 0, "the sweep covers the ambiguous groups")
    t.ok((by_phase.action_sweep or 0) <= ambiguous,
         "and never more of them than the catalog actually has open")
end

-- =========================================================
t.group("button bits - what it refuses to conclude")

-- Drives the button phase with a table of bit -> action id.
local function run_bits(s, neutral, produced)
    local steps = Calibration.plan(s)
    for _, st in ipairs(steps) do
        if st.phase == "neutral" then
            Calibration.observe(s, st.id, { action_id = neutral })
        elseif st.phase == "button_bits" then
            Calibration.observe(s, st.id, { action_id = produced[st.bit] or neutral })
        end
    end
end

do
    local s = new_session()
    -- Every bit produces nothing at all.
    run_bits(s, 1, {})
    local rep = Calibration.conclude(s)
    t.is_nil(rep.values.modern_button_bits, "a sweep where nothing came out concludes nothing")
    t.ok(#rep.problems.button_bits == 8, "and every dead bit is recorded")
end

do
    local s = new_session()
    -- One bit produces a light attack; the other seven produce nothing. Six of
    -- eight buttons therefore have no bit.
    run_bits(s, 1, { [0x10] = 611 })
    local rep = Calibration.conclude(s)
    t.is_nil(rep.values.modern_button_bits,
             "a partial map is refused - a profile that cannot press two of the buttons "
             .. "would still report injection as available")
    local why
    for _, n in ipairs(rep.notes) do
        if n.key == "modern_button_bits" then why = n.reason end
    end
    t.ok(tostring(why):find("no bit was found for"), "and names the buttons still missing")
end

do
    local s = new_session()
    -- Two different bits produce the same button's action.
    run_bits(s, 1, { [0x10] = 611, [0x20] = 611 })
    local rep = Calibration.conclude(s)
    local dup = false
    for _, p in ipairs(rep.problems.button_bits) do
        if p.reason == "two bits produced the same button" then dup = true end
    end
    t.ok(dup, "two bits mapping to one button is reported rather than silently overwritten")
end

do
    local s = new_session()
    -- An action id that belongs to no single-button notation at all.
    run_bits(s, 1, { [0x10] = 999999 })
    local rep = Calibration.conclude(s)
    local unknown = false
    for _, p in ipairs(rep.problems.button_bits) do
        if tostring(p.reason):find("belongs to no single%-button notation") then unknown = true end
    end
    t.ok(unknown, "an unrecognisable action is a finding, not a mapping")
end

-- =========================================================
t.group("direction and polarity")

-- own_pos_before / after and the opponent, per (side, direction).
local function run_dirs(s, moves)
    for _, st in ipairs(Calibration.plan(s)) do
        if st.phase == "direction" then
            local m = moves[st.side] and moves[st.side][st.direction]
            if m then Calibration.observe(s, st.id, m) end
        end
    end
end

-- P1 on the left (opponent at +10) with rl_dir truthy; P1 on the right
-- (opponent at -10) with rl_dir falsy. RIGHT walks forward on the first and
-- backward on the second, which is the mirror_when_falsy case.
local FORWARD_ON_TRUTHY = {
    rl_dir_truthy = {
        RIGHT = { own_pos_before = 0, own_pos_after = 1, opponent_pos = 10, rl_dir = true },
        LEFT  = { own_pos_before = 0, own_pos_after = -1, opponent_pos = 10, rl_dir = true },
    },
    rl_dir_falsy = {
        RIGHT = { own_pos_before = 0, own_pos_after = 1, opponent_pos = -10, rl_dir = false },
        LEFT  = { own_pos_before = 0, own_pos_after = -1, opponent_pos = -10, rl_dir = false },
    },
}

do
    local s = new_session()
    run_dirs(s, FORWARD_ON_TRUTHY)
    local rep = Calibration.conclude(s)
    t.eq(rep.values.rl_dir_polarity.value, "mirror_when_falsy",
         "RIGHT went forward only where rl_dir was truthy, so the falsy side is the one to flip")
    t.eq(rep.values.rl_dir_polarity.status, "verified", "which is what the guess said")
    t.ok(rep.values.direction_bits ~= nil, "and LEFT/RIGHT came out opposite, confirming the bits")
end

do
    local s = new_session()
    -- Only one side sampled.
    local half = { rl_dir_truthy = FORWARD_ON_TRUTHY.rl_dir_truthy }
    run_dirs(s, half)
    local rep = Calibration.conclude(s)
    t.is_nil(rep.values.rl_dir_polarity,
             "one side cannot answer the polarity question - it is consistent with both answers")
end

do
    local s = new_session()
    -- RIGHT goes forward on BOTH sides: the game is mirroring the written mask
    -- itself, which is neither of the two values the register accepts.
    local both = {
        rl_dir_truthy = FORWARD_ON_TRUTHY.rl_dir_truthy,
        rl_dir_falsy = {
            RIGHT = { own_pos_before = 0, own_pos_after = -1, opponent_pos = -10, rl_dir = false },
            LEFT  = { own_pos_before = 0, own_pos_after = 1, opponent_pos = -10, rl_dir = false },
        },
    }
    run_dirs(s, both)
    local rep = Calibration.conclude(s)
    t.is_nil(rep.values.rl_dir_polarity, "a third case is refused rather than rounded to the nearer one")
    local why
    for _, n in ipairs(rep.notes) do
        if n.key == "rl_dir_polarity" then why = n.reason end
    end
    t.ok(tostring(why):find("the game mirrors"), "and it says what it saw instead: " .. tostring(why))
end

-- =========================================================
t.group("the canonical sweep goes through the catalog")

do
    local s = new_session()
    local steps = Calibration.plan(s)

    -- Answer every ambiguous group with its own first candidate.
    for _, st in ipairs(steps) do
        if st.phase == "action_sweep" then
            Calibration.observe(s, st.id, { action_id = st.candidates[1] })
        end
    end
    local rep = Calibration.conclude(s)

    local resolved = 0
    for _, g in ipairs(Catalog.ambiguous_groups(s.catalog)) do
        if g.canonical_status == "verified" then resolved = resolved + 1 end
    end
    t.ok(resolved > 0, "observations reach the catalog and resolve groups there")
end

do
    local s = new_session()
    local steps = Calibration.plan(s)
    -- One group answered with an id that is not one of its candidates.
    for _, st in ipairs(steps) do
        if st.phase == "action_sweep" then
            Calibration.observe(s, st.id, { action_id = 999999 })
            break
        end
    end
    local rep = Calibration.conclude(s)
    t.ok(#rep.problems.action_sweep > 0,
         "an id outside the group is carried back as a conflict, not adopted")
    t.is_nil(rep.values.action_id_canonical, "and the entry stays unsettled")
end

do
    local s = new_session()
    -- Nothing observed at all.
    local rep = Calibration.conclude(s)
    t.is_nil(rep.values.action_id_canonical, "an unrun sweep resolves nothing")
    t.eq(rep.steps_observed, 0, "and says how much of the plan was actually run")
    t.ok(rep.steps_total > 0, "against how much there was")
end

-- =========================================================
t.group("degenerate input")

do
    local s, err = Calibration.new({})
    t.is_nil(s, "a session without a catalog is refused")
    t.ok(err ~= nil, "with a reason")
end

do
    local s = new_session()
    local ok, why = Calibration.observe(s, "no-such-step", { action_id = 1 })
    t.eq(ok, false, "an observation for a step that is not in the plan is refused")
    t.ok(tostring(why):find("no such step"), "by name")
end

do
    local s = new_session()
    local ok = Calibration.observe(s, Calibration.plan(s)[1].id, "not a table")
    t.eq(ok, false, "and a non-table observation is refused")
end
