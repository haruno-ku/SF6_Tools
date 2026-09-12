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
local InputMask   = require("func/ComboExplorer/core/InputMask")

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
    t.eq(by_phase.direction, 6,
         "LEFT and RIGHT on both sides, plus UP and DOWN once each")

    -- Counted per direction rather than only in total, because the total is the
    -- same whether UP and DOWN are swept once each or LEFT is swept four times.
    local per_dir, sided = {}, {}
    for _, st in ipairs(steps) do
        if st.phase == "direction" then
            per_dir[st.direction] = (per_dir[st.direction] or 0) + 1
            if st.side ~= nil then sided[st.direction] = true end
        end
    end
    t.eq(per_dir.LEFT, 2, "LEFT twice")
    t.eq(per_dir.RIGHT, 2, "RIGHT twice")
    t.eq(per_dir.UP, 1, "UP once - facing has nothing to do with whether up is up")
    t.eq(per_dir.DOWN, 1, "DOWN once, for the same reason")
    t.ok(sided.LEFT and sided.RIGHT, "the horizontal steps name a side")
    t.is_nil(sided.UP, "and the vertical ones do not, so the FSM never gates them")
    t.is_nil(sided.DOWN, "neither of them")

    -- The vertical bits used to be guessed and never pressed. If the plan stops
    -- pressing them the guess silently becomes an assumption again, and it
    -- builds six of the nine numpad digits.
    local dir_masks = {}
    for _, st in ipairs(steps) do
        if st.phase == "direction" then dir_masks[st.mask] = true end
    end
    local guess = Provenance.provisional(s.provenance, "direction_bits")
    for _, name in ipairs({ "UP", "DOWN", "LEFT", "RIGHT" }) do
        t.ok(dir_masks[guess[name]] == true,
             ("the bit guessed for %s is actually written at some point"):format(name))
    end

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
t.group("a silent action sweep observes nothing")

-- CalibrationFsm substitutes the neutral action id when a step pressed
-- something and nothing came out. That is deliberate: conclude_button_bits
-- needs the shape to report "produced no action".
--
-- Submitted to Catalog.apply_observations it becomes a claim that the notation
-- produces the idle action, which is not what happened - and the catalog then
-- reports "observed action id is not in the group", one fabricated conflict per
-- ambiguous group.
--
-- Which is worse than noise. A group seen to conflict never returns to
-- verified, on purpose, so a fabricated conflict is PERMANENT: no later sweep,
-- however clean, can undo it.
do
    local s = new_session()
    local steps = Calibration.plan(s)
    local NEUTRAL = 1
    local swept = 0
    for _, st in ipairs(steps) do
        if st.phase == "neutral" then
            Calibration.observe(s, st.id, { action_id = NEUTRAL })
        elseif st.phase == "action_sweep" then
            swept = swept + 1
            -- Pressed, nothing came out: the FSM hands over the neutral id.
            Calibration.observe(s, st.id, { action_id = NEUTRAL })
        end
    end
    t.ok(swept > 0, "the plan pressed some ambiguous groups (" .. swept .. ")")

    local rep = Calibration.conclude(s)
    -- The real field. `rep.conflicts` does not exist, and asserting on it
    -- counted a nil table - which is how a vacuous test looks from the inside.
    t.eq(#rep.problems.action_sweep, 0, "a silent sweep manufactures no conflicts")
    t.is_nil(rep.values.action_id_canonical,
             "so the canonical entry is not settled by silence")

    local why = ""
    for _, n in ipairs(rep.notes or {}) do
        if n.key == "action_id_canonical" then why = tostring(n.reason) end
    end
    t.ok(why:find("produced no action") ~= nil,
         "and the skip reason says they were pressed and produced nothing: " .. why)

    -- The groups must still be open, not poisoned.
    local conflicting = 0
    for _, g in ipairs(Catalog.ambiguous_groups(s.catalog)) do
        if g.canonical_status == "conflicting" then conflicting = conflicting + 1 end
    end
    t.eq(conflicting, 0, "and no group was permanently marked conflicting")
end

-- A real observation still gets through, or the guard above would have bought
-- safety by making the sweep useless.
do
    local s = new_session()
    local steps = Calibration.plan(s)
    local NEUTRAL = 1
    -- A group is keyed on notation AND input method - the same display under two
    -- methods is two inputs - so the step has to be matched on both.
    local target
    for _, st in ipairs(steps) do
        if st.phase == "action_sweep" and not target then target = st end
    end
    t.ok(target ~= nil, "the plan has an action-sweep step to answer")
    local real_id
    for _, g in ipairs(Catalog.ambiguous_groups(s.catalog)) do
        if g.notation == target.notation and g.input_method == target.input_method then
            real_id = g.action_ids[1]
        end
    end
    t.ok(real_id ~= nil, "and the group it addresses has an action id to produce")

    for _, st in ipairs(steps) do
        if st.phase == "neutral" then
            Calibration.observe(s, st.id, { action_id = NEUTRAL })
        elseif st.phase == "action_sweep" then
            Calibration.observe(s, st.id,
                { action_id = (st.id == target.id) and real_id or NEUTRAL })
        end
    end
    local rep = Calibration.conclude(s)
    t.eq(#rep.problems.action_sweep, 0, "no conflict from the silent steps alongside it")

    -- Checked against the catalog rather than the report, because the report
    -- does not expose the applied list - and because the catalog is where the
    -- answer has to land for anything downstream to see it.
    local resolved
    for _, g in ipairs(Catalog.ambiguous_groups(s.catalog)) do
        if g.notation == target.notation and g.input_method == target.input_method then
            resolved = g
        end
    end
    t.ok(resolved ~= nil, "the group that really produced something is still findable")
    t.eq(resolved.canonical_status, "verified",
         "and the observation resolved it - the guard buys safety without making "
         .. "the sweep useless")
    t.eq(resolved.canonical_action_id, real_id, "to the id that actually came out")
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
    -- One bit produces a light attack; the other seven produce nothing, so
    -- seven of the eight buttons have no bit.
    --
    -- This used to be refused outright, on the grounds that a map missing a
    -- button would silently press nothing. It is settled now, as `partial`,
    -- because that is not where the safety lives - see the group below, which
    -- pins the thing that actually prevents the whiff.
    run_bits(s, 1, { [0x10] = 611 })
    local rep = Calibration.conclude(s)
    local v = rep.values.modern_button_bits
    t.ok(v ~= nil, "a map with holes in it is reported, not thrown away")
    if v then
        t.eq(v.status, "partial", "as partial: nothing contradicted the guess, most was not seen")
        t.eq(v.value.L, 0x10, "the one bit that was witnessed is in the map")
        t.is_nil(v.value.H, "and the ones that were not are absent, rather than guessed")
        -- The operator has to be able to tell one missing route from six
        -- hundred, so the cost travels with the name.
        t.ok(tostring(v.note):find("no bit for H"), "the note names H: " .. tostring(v.note))
        t.ok(tostring(v.note):find("probeable row%(s%) need it"),
             "and says how many rows each one costs")
    end
end

do
    -- What a button being absent from the map actually costs, and why that is
    -- safe. InputMask.compile asks button_mask for every route and refuses the
    -- ones it cannot express, BY NAME. That refusal is what stops a trial from
    -- pressing nothing and recording "these two moves do not link" - not the
    -- completeness check that used to sit in conclude_button_bits.
    local InputMask = require("func/ComboExplorer/core/InputMask")
    local profile = InputMask.profile({
        buttons = { L = 0x10, M = 0x80 },     -- no H
        dir = { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 },
        mirror_when = "falsy", status = "partial", measured = true,
    })
    t.ok(profile ~= nil, "a partial profile is a profile")

    local light = InputMask.compile(InputMask.parse("\229\188\177"), { profile = profile })
    t.ok(light ~= nil, "a route using a button the map HAS still compiles")

    local heavy, err = InputMask.compile(InputMask.parse("\229\188\186"), { profile = profile })
    t.is_nil(heavy, "a route using a button the map lacks does NOT compile")
    t.ok(tostring(err):find("H"), "and the refusal names the button: " .. tostring(err))
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

    -- The assertion that was missing, and the reason the defect survived: this
    -- block checked that direction_bits EXISTS and never what it said.
    --
    -- conclude_direction used to return the whole four-key guess, so
    -- verdict_status compared it against a copy of itself and could return
    -- nothing but VERIFIED - stamping the entry that gates INJECTION as measured
    -- with UP and DOWN never once held. Those two build six of the nine numpad
    -- digits: every crouching normal, and the down leg of every 236, 214 and 623.
    local d = rep.values.direction_bits
    t.eq(d.status, "partial",
         "the sweep pressed LEFT and RIGHT, so the entry is PARTIAL, not verified")
    t.eq_list(d.unwitnessed, { "DOWN", "UP" }, "and names the two it never pressed")
    t.eq(d.value.LEFT, 4, "the bits it did measure are there")
    t.eq(d.value.RIGHT, 8, "both of them")
    t.is_nil(d.value.UP, "and the ones it did not are absent, not copied from the guess")
    t.is_nil(d.value.DOWN, "neither of them")
end

-- The other half of the same phase: the two steps that hold UP and DOWN.
-- `run_dirs` cannot drive these - it indexes `moves[st.side]` and these steps
-- name no side - so the two halves are run separately, which is also how the
-- blocks below vary one without touching the other.
local function run_vertical(s, neutral, produced)
    for _, st in ipairs(Calibration.plan(s)) do
        if st.phase == "neutral" then
            Calibration.observe(s, st.id, { action_id = neutral })
        elseif st.phase == "direction" and st.side == nil then
            local id = produced[st.direction]
            if id ~= nil then Calibration.observe(s, st.id, { action_id = id }) end
        end
    end
end

local function vertical_problem(rep, needle)
    for _, pr in ipairs(rep.problems.direction) do
        if tostring(pr.reason):find(needle) then return pr end
    end
end

do
    local s = new_session()
    run_dirs(s, FORWARD_ON_TRUTHY)
    -- Crouch and jump, whichever is which. 7 is the idle id the other blocks use.
    run_vertical(s, 7, { UP = 800, DOWN = 900 })
    local rep = Calibration.conclude(s)

    local d = rep.values.direction_bits
    t.eq(d.status, "verified",
         "all four bits were actually held, so nothing is left unwitnessed")
    t.is_nil(d.unwitnessed, "and there is no list of excuses")
    t.eq(d.value.UP, 1, "the vertical bits are in the value now")
    t.eq(d.value.DOWN, 2, "both of them")
    t.eq(d.value.LEFT, 4, "alongside the horizontal pair")
    t.eq(d.value.RIGHT, 8, "which did not change")
end

do
    -- One of the two bits does nothing. That is the failure the steps exist to
    -- catch: a bit that is not a direction at all means every crouching normal
    -- and the down leg of every 236 silently presses nothing.
    local s = new_session()
    run_dirs(s, FORWARD_ON_TRUTHY)
    run_vertical(s, 7, { UP = 800, DOWN = 7 })
    local rep = Calibration.conclude(s)

    local d = rep.values.direction_bits
    t.eq(d.status, "partial", "a bit that produced no action is not a measured bit")
    t.eq_list(d.unwitnessed, { "DOWN", "UP" },
              "and NEITHER vertical bit is claimed - UP is only credible as half "
              .. "of a pair that did two different things")
    local pr = vertical_problem(rep, "not that direction")
    t.ok(pr ~= nil, "the finding is reported")
    t.eq(pr and pr.direction, "DOWN", "against the bit that failed")
end

do
    -- Both bits held, both produced the SAME action. Something came out, so a
    -- per-step check passes, but the two bits are not two directions.
    local s = new_session()
    run_dirs(s, FORWARD_ON_TRUTHY)
    run_vertical(s, 7, { UP = 800, DOWN = 800 })
    local rep = Calibration.conclude(s)

    t.eq(rep.values.direction_bits.status, "partial",
         "two bits with one action between them is not two directions")
    local pr = vertical_problem(rep, "same action")
    t.ok(pr ~= nil, "and it says so rather than passing on the count alone")
    t.eq(pr and pr.action_id, 800, "naming the id both produced")
end

do
    -- The plan has the steps; the operator stopped before running them.
    local s = new_session()
    run_dirs(s, FORWARD_ON_TRUTHY)
    run_vertical(s, 7, { UP = 800 })
    local rep = Calibration.conclude(s)

    t.eq(rep.values.direction_bits.status, "partial", "a step nobody ran measures nothing")
    local pr = vertical_problem(rep, "not run")
    t.ok(pr ~= nil and pr.direction == "DOWN",
         "and the unrun step is named, not silently treated as a pass")
end

do
    -- The neutral step is what "left neutral" is measured against. Without it
    -- there is no baseline, and guessing one would be the whole bug.
    local s = new_session()
    run_dirs(s, FORWARD_ON_TRUTHY)
    for _, st in ipairs(Calibration.plan(s)) do
        if st.phase == "direction" and st.side == nil then
            Calibration.observe(s, st.id, { action_id = st.direction == "UP" and 800 or 900 })
        end
    end
    local rep = Calibration.conclude(s)

    t.eq(rep.values.direction_bits.status, "partial",
         "two different ids came out, but with no baseline neither is known to be an action")
    local pr = vertical_problem(rep, "neutral step was never run")
    t.ok(pr ~= nil, "and the report says which measurement is missing: "
         .. tostring(pr and pr.reason))
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

-- =========================================================
-- Everything below fixes a bug that shipped. Each one made the sweep produce a
-- confident wrong answer, or no answer at all, on every possible run - and the
-- tests above all passed while it did, because none of them drove the path.
-- =========================================================

t.group("every step presses something, and says whether it may be flipped")

do
    local s = new_session()
    local steps = Calibration.plan(s)

    local no_mask = {}
    for _, st in ipairs(steps) do
        if st.mask == nil then no_mask[#no_mask + 1] = st.id end
    end
    -- The action sweep used to carry no mask at all. Nothing was pressed, the
    -- step completed normally, and the IDLE action id was recorded against the
    -- notation - a confident wrong observation per ambiguous group, no error.
    t.eq(#no_mask, 0, "no step reaches the writer without a mask")

    for _, st in ipairs(steps) do
        if st.phase == "direction" then
            -- The whole correctness of #8. Mirroring here would feed the
            -- provisional polarity into the experiment that measures it.
            t.eq(st.mirror, false, "a direction step is never mirrored: " .. st.id)
        elseif st.phase == "button_bits" then
            t.eq(st.mirror, false, "a lone button bit has no left or right: " .. st.id)
        elseif st.phase == "action_sweep" then
            t.eq(st.mirror, true, "a player-relative notation is mirrored: " .. st.id)
            t.ok(st.mask > 0, "and it presses something: " .. st.notation)
        end
    end
end

do
    local s = new_session()
    Calibration.plan(s)
    -- A group the sweep cannot press is recorded with its reason, not dropped.
    -- Counting those as "unresolved" is what made action_id_canonical
    -- unsettleable on every character.
    t.ok(#s.groups_unaddressed > 0, "the groups out of reach are listed")
    local motion, air = false, false
    for _, u in ipairs(s.groups_unaddressed) do
        t.ok(u.reason ~= nil and u.reason ~= "", "each with a reason: " .. tostring(u.notation))
        if tostring(u.reason):find("direction ticks") then motion = true end
        if tostring(u.reason):find("air move") then air = true end
    end
    t.ok(motion, "a multi-direction motion is named as out of reach, not silently skipped")
    t.ok(air, "so is an air move")
end

t.group("a clean sweep actually settles the button map")

-- The buttons this catalog can witness: those with a notation naming exactly
-- one button and no direction. Derived here the same way the module does,
-- rather than hardcoded, so the test says what it means.
local function derivable_buttons(cat)
    local out = {}
    for _, g in pairs(cat.groups) do
        local parsed = InputMask.parse(g.notation)
        if parsed and not parsed.followup and not parsed.air and not parsed.any_button
            and parsed.dirs == "" and #parsed.buttons == 1 then
            local name = parsed.buttons[1]
            if not out[name] then out[name] = g.action_ids[1] end
        end
    end
    return out
end

do
    local s = new_session()
    local steps = Calibration.plan(s)
    local witnessable = derivable_buttons(s.catalog)

    local names = {}
    for name in pairs(witnessable) do names[#names + 1] = name end
    table.sort(names)
    t.ok(#names > 0, "the fixture catalog can witness some buttons")

    -- AUTO only ever appears as "AUTO + <strength>" and PARRY has no InputMask
    -- token at all, so no catalog can witness either. Judging completeness
    -- against the guess's eight keys meant `missing` was never empty and the
    -- entry that gates INJECTION was skipped on every possible run.
    local has_auto = false
    for _, n in ipairs(names) do if n == "AUTO" then has_auto = true end end
    t.eq(has_auto, false, "AUTO has no single-button notation, so it can never be witnessed")

    Calibration.observe(s, steps[1].id, { action_id = 1 })

    local i = 0
    for _, st in ipairs(steps) do
        if st.phase == "button_bits" then
            i = i + 1
            local name = names[i]
            Calibration.observe(s, st.id, { action_id = name and witnessable[name] or 1 })
        end
    end

    local rep = Calibration.conclude(s)
    local v = rep.values.modern_button_bits
    t.ok(v ~= nil, "a sweep that witnessed every witnessable button settles the map")
    if v then
        for _, n in ipairs(names) do
            t.ok(v.value[n] ~= nil, "the map carries a bit for " .. n)
        end
        t.ok(tostring(v.note):find("AUTO"),
             "and the note names what could not be witnessed: " .. tostring(v.note))
        t.is_nil(v.value.AUTO, "a button nobody could witness is absent from the map, not guessed")
    end
end

t.group("a flawless sweep and a wrong one do not look the same")

-- They used to. The derived map can never contain AUTO or PARRY - no shipped
-- catalog has a single-button notation for either - so a subset was the NORMAL
-- outcome, and verdict_status returned the bare constant REFUTED for it. A
-- sweep where every witnessable button landed exactly where the guess said, and
-- a sweep that got two buttons backwards, produced byte-identical verdicts.
--
-- A status that cannot tell success from failure is not a status.

-- Drives the button phase so that each bit produces the action id of the button
-- THE GUESS SAYS that bit is. `swap` crosses L and M, which is a real
-- disagreement rather than a gap.
local function run_bits_as_guessed(s, swap)
    local steps = Calibration.plan(s)
    local witnessable = derivable_buttons(s.catalog)
    local provisional = Provenance.provisional(s.provenance, "modern_button_bits")
    local name_of = {}
    for name, bit in pairs(provisional) do name_of[bit] = name end

    Calibration.observe(s, steps[1].id, { action_id = 1 })
    for _, st in ipairs(steps) do
        if st.phase == "button_bits" then
            local name = name_of[st.bit]
            if swap and (name == "L" or name == "M") then
                name = (name == "L") and "M" or "L"
            end
            Calibration.observe(s, st.id, { action_id = (name and witnessable[name]) or 1 })
        end
    end
    return Calibration.conclude(s)
end

do
    local perfect = run_bits_as_guessed(new_session(), false).values.modern_button_bits
    local swapped = run_bits_as_guessed(new_session(), true).values.modern_button_bits

    t.ok(perfect ~= nil, "a flawless sweep settles the map")
    t.ok(swapped ~= nil, "and so does one with two buttons crossed")

    t.eq(perfect.status, "partial",
         "the flawless one is PARTIAL - nothing disagreed, but AUTO and PARRY "
         .. "were never witnessed")
    t.eq(swapped.status, "refuted", "the crossed one is REFUTED - the guess was wrong")
    t.ok(perfect.status ~= swapped.status,
         "and the two are distinguishable, which is the whole point")

    -- The reason is structured, not only in the prose. A consumer that needs
    -- one of these buttons has to be able to find out it is missing without
    -- parsing a sentence.
    t.ok(perfect.unwitnessed ~= nil, "the flawless sweep says what it could not witness")
    t.eq_list(perfect.unwitnessed, { "AUTO", "PARRY" }, "by name")
    t.is_nil(perfect.value.AUTO, "and the map does not carry a guess for it")
    t.is_nil(swapped.unwitnessed,
             "a refuted verdict reports no unwitnessed list - the disagreement is "
             .. "the finding, and stopping at it is deliberate")
end

-- partial is a MEASUREMENT: the register must accept it and the capability it
-- gates must open. Refusing it would be the "blocked by being right" failure
-- that Provenance already fixed once for refuted.
do
    local rep = run_bits_as_guessed(new_session(), false)
    local doc, err = Calibration.document(IDENTITY, { rep.values })
    t.ok(doc ~= nil, "a partial verdict still makes a document: " .. tostring(err))

    local reg = Provenance.new()
    local applied, rejected = reg:apply_calibration(doc)
    local names = {}
    for _, k in ipairs(applied) do names[k] = true end
    t.ok(names.modern_button_bits,
         "and the register accepts it (" .. #applied .. " applied, " ..
         #rejected .. " rejected)")
    t.eq(Provenance.get(reg, "modern_button_bits").status, "partial",
         "keeping the distinction rather than flattening it to verified")
    t.eq(Provenance.is_measured(reg, "modern_button_bits"), true,
         "partial counts as measured - somebody looked")
    t.eq(Provenance.is_verified(reg, "modern_button_bits"), false,
         "but not as verified, because part of it was never seen")
end

t.group("the canonical entry settles on what the sweep could press")

do
    local s = new_session()
    local steps = Calibration.plan(s)
    for _, st in ipairs(steps) do
        if st.phase == "action_sweep" then
            Calibration.observe(s, st.id, { action_id = st.candidates[1] })
        end
    end
    local rep = Calibration.conclude(s)
    -- Every group the plan pressed resolved. The ones it could not press are
    -- out of the sweep's reach, not outstanding questions about this run - and
    -- counting them kept this entry permanently unsettleable.
    t.ok(rep.values.action_id_canonical ~= nil,
         "action_id_canonical settles when every group the sweep pressed resolved")
    if rep.values.action_id_canonical then
        t.ok(tostring(rep.values.action_id_canonical.note):find("out of this sweep's reach"),
             "and the note still says how many were out of reach")
    end
end


-- =========================================================
t.group("the buttons a single bit can never witness")

-- #47, measured on build 24176760. conclude_button_bits reads a bit's identity
-- off a SINGLE-button notation containing the action the bit produced. AUTO has
-- no single-button notation on any shipped catalog - only "AUTO + <strength>" -
-- so it was reported unwitnessed on every possible run, and every route needing
-- it was refused by name: 22 of 378 worklist pairs, and the whole of
-- assist-started combos.
--
-- "AUTO + 弱" IS a notation, and 弱 the single-bit phase does witness. So hold a
-- candidate bit with the partner's bit and ask the same question of the pair's
-- group.

-- An action id from a group the MODULE accepted for this step.
--
-- Looked up through the step's own `pair_notations` rather than by re-deciding
-- which groups count. The first version of this helper re-implemented the
-- filter and got it subtly wrong: it returned an id from a group the module
-- excludes, so the test held the right bit, observed an id the catalog really
-- does carry, and the module correctly refused to recognise it. The failure
-- looked like a bug in the module.
local function pair_action_id(cat, step)
    local want = {}
    for _, n in ipairs(step.pair_notations or {}) do want[n] = true end
    for _, g in pairs(cat.groups or {}) do
        if want[g.notation] then
            local id = (g.action_ids or {})[1]
            if id then return id end
        end
    end
end

do
    local s = new_session()
    local steps = Calibration.plan(s)

    local paired = {}
    for _, st in ipairs(steps) do
        if st.phase == "paired_button" then paired[#paired + 1] = st end
    end
    t.ok(#paired > 0, "the plan presses the bits it cannot otherwise witness")

    local buttons, partner_bits = {}, {}
    for _, st in ipairs(paired) do
        buttons[st.button] = true
        partner_bits[st.partner_bit] = true
        t.eq(st.mask, st.bit | st.partner_bit, "each step holds the two bits together")
        t.ok(st.bit ~= st.partner_bit, "and never the partner's bit twice")
        t.eq(st.mirror, false, "buttons carry no side, so nothing is mirrored")
    end
    t.ok(buttons.AUTO, "AUTO is one of them")
    t.is_nil(buttons.L, "a button with its own single-button notation is not")

    -- Every bit but the partner's, because WHICH bit is AUTO is the question.
    -- Sweeping only the guess would assume the answer, which is the same
    -- mistake the single-bit phase is written to avoid.
    --
    -- Counted against the whole button field, NOT against the provisional map's
    -- bits. Measured on build 24176760: the map had already lost AUTO - and
    -- with it AUTO's 0x200 - so a phase that swept the map's bits could never
    -- press the bit it was looking for. The plan emitted zero steps on the
    -- machine while this test was green.
    local n_field = 0
    do
        local bit = 1
        while bit <= 0x8000 do
            if (InputMask.BTN_BITS & bit) ~= 0 then n_field = n_field + 1 end
            bit = bit << 1
        end
    end
    local auto_steps, partner_bit = 0, nil
    for _, st in ipairs(paired) do
        if st.button == "AUTO" then auto_steps = auto_steps + 1; partner_bit = st.partner_bit end
    end
    t.eq(auto_steps, n_field - 1, "one step per button bit in the field, minus the partner's own")
    t.ok(partner_bit ~= nil, "and the partner's bit is named on the step")
end

-- The happy path: the bit the guess named produces the pair, and AUTO settles.
do
    local s = new_session()
    local steps = Calibration.plan(s)
    local witnessable = derivable_buttons(s.catalog)
    local provisional = Provenance.provisional(s.provenance, "modern_button_bits")
    local name_of = {}
    for name, bit in pairs(provisional) do name_of[bit] = name end
    Calibration.observe(s, steps[1].id, { action_id = 1 })
    for _, st in ipairs(steps) do
        if st.phase == "button_bits" then
            local name = name_of[st.bit]
            Calibration.observe(s, st.id, { action_id = (name and witnessable[name]) or 1 })
        elseif st.phase == "paired_button" then
            -- The partner is read off the STEP, not assumed. The planner picks
            -- it by name order among the pairs whose other button has a
            -- single-button notation, and asserting "AUTO + 弱" here passed only
            -- because of which letter sorts first - a test that would go green
            -- against a planner pairing with something else entirely.
            local pair_id = pair_action_id(s.catalog, st)
            -- Only the bit the guess calls AUTO produces the pair. Every other
            -- bit held with the partner produces nothing this catalog names.
            local produced = (st.bit == provisional.AUTO) and pair_id or 1
            t.ok(produced ~= nil, "the planner picked a pair the catalog has: "
                 .. st.button .. " + " .. st.partner)
            Calibration.observe(s, st.id, { action_id = produced })
        end
    end

    local rep = Calibration.conclude(s)
    local v = rep.values.modern_button_bits
    t.ok(v ~= nil, "the entry settles")
    t.eq(v.value.AUTO, provisional.AUTO, "AUTO takes the bit that produced AUTO + 弱")
    t.eq(v.value.L, provisional.L, "and the single-bit findings are untouched")
    t.ok(tostring(v.note):find("paired step") ~= nil,
         "the note says the map came from two phases, not one: " .. tostring(v.note))
    t.is_nil((function()
        for _, u in ipairs(v.unwitnessed or {}) do
            if u.button == "AUTO" then return true end
        end
    end)(), "and AUTO is no longer reported as unwitnessed")
end

-- The refusals. Each of these would produce a WRONG bit rather than a missing
-- one, and a wrong bit presses the wrong button on every trial afterwards.
do
    -- A bit the single-bit phase already named. Holding M with L produces
    -- "L + M", a real two-button group - and read carelessly that says M is
    -- AUTO.
    local s = new_session()
    local steps = Calibration.plan(s)
    local witnessable = derivable_buttons(s.catalog)
    local provisional = Provenance.provisional(s.provenance, "modern_button_bits")
    local name_of = {}
    for name, bit in pairs(provisional) do name_of[bit] = name end
    Calibration.observe(s, steps[1].id, { action_id = 1 })
    for _, st in ipairs(steps) do
        if st.phase == "button_bits" then
            local name = name_of[st.bit]
            Calibration.observe(s, st.id, { action_id = (name and witnessable[name]) or 1 })
        elseif st.phase == "paired_button" then
            -- M's bit is the one that "produces the pair" here. It must not win.
            local pair_id = pair_action_id(s.catalog, st)
            local produced = (st.bit == provisional.M) and pair_id or 1
            Calibration.observe(s, st.id, { action_id = produced })
        end
    end

    local rep = Calibration.conclude(s)
    local v = rep.values.modern_button_bits
    t.ok(v ~= nil, "the entry still settles")
    t.is_nil(v.value.AUTO, "AUTO is NOT taken from a bit that is already M")
    t.eq(v.value.M, provisional.M, "and M keeps its own bit")
end

do
    -- No catalog groups at all: nothing to witness with, and the reason has to
    -- distinguish "no pair exists" from "the pair was pressed and never came
    -- out". They send an operator to different places.
    local cat = fresh_catalog()
    cat.groups = {}
    local s = Calibration.new({ catalog = cat })
    local steps = Calibration.plan(s)
    local n = 0
    for _, st in ipairs(steps) do if st.phase == "paired_button" then n = n + 1 end end
    t.eq(n, 0, "a catalog with no two-button notation is not swept for one")
end


-- =========================================================
t.group("bits read off the operator's pad")

-- Measured on build 24176760, in pl_input_new, by the operator pressing:
--
--   0x0200  one button   -> action 1     (the idle id: nothing came out)
--   0x0100  one button   -> action 637
--   0x0300  two buttons  -> action 660   notation "AUTO + 强"
--
-- The sweep could see none of it. 0x200 alone produces the idle id, which
-- conclude_button_bits classifies as "produced no action", so a button that
-- does nothing on its own is invisible to it - and the assist button is exactly
-- that. 660's notation names two buttons, so there was no single-button group
-- to match even when it did come out.

local function pad_row(mask, action_id, over)
    local bits, b = {}, 1
    while b <= 0x8000 do
        if (mask & b) ~= 0 then bits[#bits + 1] = b end
        b = b << 1
    end
    -- from_idle defaults TRUE: these rows stand for presses made from a
    -- standing character. The contaminated case is asserted below by passing
    -- it explicitly, because that is the one that must not derive anything.
    local r = { mask = mask, bits = bits, single_bit = (#bits == 1),
                settled = true, presses = 1, ticks = 10,
                top_action_id = action_id, first_non_idle = action_id,
                action_id = action_id, from_idle = true }
    for k, v in pairs(over or {}) do r[k] = v end
    return r
end

-- An action id whose group names exactly the two buttons asked for, taken from
-- the fixture rather than typed.
local function two_button_action(cat, want_a, want_b)
    for _, g in pairs(cat.groups or {}) do
        local parsed = InputMask.parse(g.notation)
        if parsed and #parsed.buttons == 2 and not parsed.any_button then
            local x, y = parsed.buttons[1], parsed.buttons[2]
            if (x == want_a and y == want_b) or (x == want_b and y == want_a) then
                return (g.action_ids or {})[1], g.notation
            end
        end
    end
end

do
    local cat = fresh_catalog()
    local aid, notation = two_button_action(cat, "AUTO", "H")
    t.ok(aid ~= nil, "the fixture has an AUTO + H group")

    -- H known; AUTO not. The mask has both bits, the notation names both
    -- buttons, so the bit that is not H is AUTO. No guess in that chain.
    local derived, evidence, problems = Calibration.bits_from_pad(
        { pad_row(0x300, aid) }, cat, { H = 0x100 })
    t.eq(derived.AUTO, 0x200, "the leftover bit is the leftover button")
    t.eq(#problems, 0, "with nothing to report")
    t.eq(#evidence, 1, "and the evidence is kept")
    t.eq(evidence[1].action_id, aid, "naming the action it rested on")
    t.eq(evidence[1].notation, notation, "and the notation that named the buttons")
end

do
    -- The row that defeated the sweep: a button that produces nothing alone.
    -- It must not be read as evidence about anything.
    local cat = fresh_catalog()
    local derived = Calibration.bits_from_pad({ pad_row(0x200, 1) }, cat, { H = 0x100 })
    t.is_nil(derived.AUTO, "a mask whose action belongs to no group names nothing")
end

do
    -- Nothing known: a two-button mask leaves TWO unknowns and must stay
    -- unresolved rather than guessing which bit is which.
    local cat = fresh_catalog()
    local aid = two_button_action(cat, "AUTO", "H")
    local derived = Calibration.bits_from_pad({ pad_row(0x300, aid) }, cat, {})
    t.is_nil(derived.AUTO, "two unknowns in one mask resolve neither")
    t.is_nil(derived.H, "neither of them")
end

do
    -- A contradiction is reported, not overwritten. A bit that disagrees with
    -- a measurement is the one thing that must never be applied quietly.
    local cat = fresh_catalog()
    local aid = two_button_action(cat, "AUTO", "H")
    local derived, _, problems = Calibration.bits_from_pad(
        { pad_row(0x300, aid) }, cat, { H = 0x100, AUTO = 0x800 })
    t.eq(derived.AUTO, nil, "the existing measurement is not replaced")
    t.eq(#problems, 1, "and the disagreement is named")
    t.ok(tostring(problems[1].reason):find("0x800") ~= nil,
         "carrying both readings: " .. tostring(problems[1].reason))
end

do
    -- The notation names a button whose known bit is NOT in the mask. Taking
    -- the leftover here would attribute a bit to a button on the strength of a
    -- notation that does not describe this press.
    local cat = fresh_catalog()
    local aid = two_button_action(cat, "AUTO", "H")
    local derived, _, problems = Calibration.bits_from_pad(
        { pad_row(0x300, aid) }, cat, { H = 0x4000 })
    t.is_nil(derived.AUTO, "nothing is derived from a mask that contradicts itself")
    t.ok(#problems >= 1, "and it says why: " .. tostring(problems[1] and problems[1].reason))
end

do
    -- The press that began while the PREVIOUS move was still playing. It wears
    -- that move's action id, so reading it attributes a bit to the button
    -- pressed before this one. Measured on build 24176760: it shifted a whole
    -- column by one row - 0x0080 reported 611 and 0x0100 reported 604, each
    -- mask wearing its predecessor's action.
    local cat = fresh_catalog()
    local aid = two_button_action(cat, "AUTO", "H")
    local derived = Calibration.bits_from_pad(
        { pad_row(0x300, aid, { from_idle = false }) }, cat, { H = 0x100 })
    t.is_nil(derived.AUTO, "a press that did not start from idle derives nothing")
end

do
    -- Unsettled rows are the transients a pad passes through on the way into a
    -- two-button press. Reading them would name a button from a press nobody
    -- made.
    local cat = fresh_catalog()
    local aid = two_button_action(cat, "AUTO", "H")
    local derived = Calibration.bits_from_pad(
        { pad_row(0x300, aid, { settled = false }) }, cat, { H = 0x100 })
    t.is_nil(derived.AUTO, "an unsettled row is not evidence")
end

do
    -- Order independence: a one-button row later in the list must still be
    -- usable by a two-button row, so the shorter masks are read first.
    local cat = fresh_catalog()
    local aid2 = two_button_action(cat, "AUTO", "H")
    local h_id
    for _, g in pairs(cat.groups or {}) do
        local parsed = InputMask.parse(g.notation)
        if parsed and #parsed.buttons == 1 and parsed.buttons[1] == "H"
            and parsed.dirs == "" and not parsed.any_button then
            h_id = (g.action_ids or {})[1]
        end
    end
    t.ok(h_id ~= nil, "the fixture has a single-button H group")
    local derived = Calibration.bits_from_pad(
        { pad_row(0x300, aid2), pad_row(0x100, h_id) }, cat, {})
    t.eq(derived.H, 0x100, "the single-button row names H")
    t.eq(derived.AUTO, 0x200, "and the two-button row can then name AUTO")
end

-- =========================================================
t.group("a new profile does not drop what the machine already knew")

-- The register is loaded from a profile at startup, so it is the only place the
-- measurements from previous sessions still exist. Rebuilding a profile from
-- this session's probes alone threw them away: reproduced on build 24176760,
-- latest.json went from five entries to two and three capabilities went back to
-- blocked, with nothing reported.
do
    local reg = Provenance.new()
    Provenance.apply_calibration(reg, {
        calibration_id = "yesterday", game_patch = "24176760",
        values = {
            reset_settle_ticks = { status = "refuted", value = 9, note = "probe C" },
            input_hook_calls_per_frame = { status = "verified", value = 1 },
        },
    })

    local carried = Calibration.from_register(reg)
    t.eq(carried.reset_settle_ticks.value, 9, "a measured entry is carried out of the register")
    t.eq(carried.reset_settle_ticks.status, "refuted", "with the status it was measured under")
    t.eq(carried.reset_settle_ticks.note, "probe C", "and its note")
    t.is_nil(carried.modern_button_bits,
             "an entry nobody measured is NOT carried - a guess written into a profile "
             .. "comes back as a measurement on the next load")
end

do
    -- Later wins, so a probe that has just run replaces the older value rather
    -- than being shadowed by it.
    local base = { a = { status = "verified", value = 1 },
                   b = { status = "verified", value = 2 } }
    local fresh = { b = { status = "refuted", value = 99 } }
    local m = Calibration.merge_values(base, fresh)
    t.eq(m.a.value, 1, "what only the base had survives")
    t.eq(m.b.value, 99, "and the newer measurement wins")
    t.eq(m.b.status, "refuted", "carrying its own status")
end

do
    -- The whole point, end to end: a session with NO probes run still writes a
    -- profile that keeps them.
    local reg = Provenance.new()
    Provenance.apply_calibration(reg, {
        calibration_id = "yesterday", game_patch = "24176760",
        values = { reset_settle_ticks = { status = "refuted", value = 9 } },
    })
    local no_probes = Calibration.from_probes({})     -- nothing ran this session
    local merged = Calibration.merge_values(Calibration.from_register(reg), no_probes)
    local doc = Calibration.document(IDENTITY, { merged, { rl_dir_polarity =
        { status = "verified", value = "mirror_when_falsy" } } })

    t.ok(doc ~= nil, "a document is produced")
    t.eq(doc.values.reset_settle_ticks.value, 9,
         "and yesterday's measurement is still in it after a sweep with no probes run")
    t.eq(doc.values.rl_dir_polarity.value, "mirror_when_falsy", "alongside today's")

    local fresh = Provenance.new()
    Provenance.apply_calibration(fresh, doc)
    t.eq(Provenance.can(fresh, "stage_reset"), true,
         "so the capability it gates does not close again on the next load")
end

return t.finish()
