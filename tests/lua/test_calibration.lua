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
