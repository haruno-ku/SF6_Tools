-- Unit tests for func/ComboExplorer/runtime/Injector.lua
--
-- This is the module core/Provenance.lua's INJECTION capability has existed for
-- since the first commit. `Provenance.can` had never been called from anywhere
-- in the shipping code; this is its first caller, so the gate itself is under
-- test here for the first time as well.
--
-- The adapter is a table, and start() reaches for the real one LAST - after
-- every refusal - so a register with nothing measured can be handed to it on a
-- machine with no Street Fighter.

local t = require("tests.lua.harness")
local Injector = require("func/ComboExplorer/runtime/Injector")
local Provenance = require("func/ComboExplorer/core/Provenance")
local InputMask = require("func/ComboExplorer/core/InputMask")

-- --- registers ----------------------------------------------------------------

local INJECTION_KEYS = { "modern_button_bits", "direction_bits", "rl_dir_polarity" }

local function fresh_register()
    return Provenance.new()
end

-- A register with the three injection entries settled. Their VALUES are the
-- provisional ones - this is a statement about the test, not an endorsement of
-- the guessed bit table.
local function measured_register()
    local reg = Provenance.new()
    for _, key in ipairs(INJECTION_KEYS) do
        reg.entries[key].status = Provenance.STATUS.VERIFIED
    end
    return reg
end

local ROUTE = {
    id = "r-inject-test",
    character = "zangief",
    control_scheme = "modern",
    steps = {
        { index = 1, action_id = 601, input_method = "manual",
          notation = "\229\188\177" },                  -- 弱
        { index = 2, action_id = 621, input_method = "manual",
          notation = "2 + \228\184\173" },              -- 2 + 中
    },
}

local SINK = { path = "ComboExplorer_data/trials/test.jsonl",
               dirs = { "ComboExplorer_data", "ComboExplorer_data/trials" } }

-- --- the gate -------------------------------------------------------------------

t.group("the gate the whole project is built around")

do
    local ok, why = Injector.start({ provenance = fresh_register(),
                                     allow_injection = true, route = ROUTE,
                                     delay = 4, sink = SINK })
    t.is_nil(ok, "a register with nothing measured cannot start a trial")
    t.ok(tostring(why):find("injection is blocked") ~= nil,
         "and says injection is blocked: " .. tostring(why))

    -- The refusal names them. A gate that says only "blocked" sends the
    -- operator to the source; this one sends them to the sweep.
    for _, key in ipairs(INJECTION_KEYS) do
        t.ok(tostring(why):find(key, 1, true) ~= nil,
             ("naming %s as one of the things to measure"):format(key))
    end
end

do
    local ok, why = Injector.start({ allow_injection = true, route = ROUTE, sink = SINK })
    t.is_nil(ok, "no register at all is refused")
    t.ok(tostring(why):find("no provenance register") ~= nil, "plainly: " .. tostring(why))
end

do
    -- The operator's own switch, checked AFTER the register. The register is
    -- the real gate; this is the second one.
    local ok, why = Injector.start({ provenance = measured_register(),
                                     allow_injection = false, route = ROUTE,
                                     delay = 4, sink = SINK })
    t.is_nil(ok, "a measured register still will not run with the switch off")
    t.ok(tostring(why):find("switched off") ~= nil,
         "and says it is the switch, not the register: " .. tostring(why))
end

do
    -- The calibration sweep is allowed to write with an UNMEASURED map because
    -- it is testing it. This is not, and the difference is what the gate is for.
    local reg = measured_register()
    local profile = InputMask.profile_from_provenance(Provenance, reg)
    t.eq(profile.measured, true, "a settled register produces a measured profile")

    local bare = InputMask.profile_from_provenance(Provenance, fresh_register())
    t.eq(bare.measured, false, "and an untouched one does not")
end

-- --- the sink -------------------------------------------------------------------

t.group("a trial whose result is not written did not happen")

do
    local sink, why = Injector.open_sink(nil)
    t.is_nil(sink, "no sink is a refusal, not a default")
    t.ok(tostring(why):find("did not happen") ~= nil, "and says why: " .. tostring(why))

    local off = Injector.open_sink(false)
    t.eq(off, false, "and `false` is the way to say recording is off on purpose")
end

do
    -- The encoder is checked once, at the start, rather than per record. On a
    -- build whose REFramework has no json.dump_string this refuses before the
    -- first trial instead of discovering it an hour in with the results gone.
    -- On this machine there is no json at all, which is the same path.
    local sink, why = Injector.open_sink(SINK)
    t.is_nil(sink, "with no encoder available the sink refuses to open")
    t.ok(tostring(why):find("cannot encode") ~= nil,
         "naming the encoder rather than the file: " .. tostring(why))
end

-- --- the tick counts ------------------------------------------------------------

t.group("the budgets the runner will not default")

do
    local RunnerFsm = require("func/ComboExplorer/core/RunnerFsm")
    for _, req in ipairs(RunnerFsm.REQUIRED) do
        t.ok(Injector.DEFAULTS[req.key] ~= nil,
             ("the shipped defaults supply %s"):format(req.key))
        t.ok(Injector.PROVENANCE[req.key] ~= nil,
             ("and say where %s came from"):format(req.key))
        t.ok(tostring(Injector.PROVENANCE[req.key]):find("guessed") ~= nil,
             ("%s is marked a guess, because it is one"):format(req.key))
    end

    -- The budget has to cover the program plus the window, or every trial times
    -- out and a sweep of timeouts looks like a sweep of hardware trouble.
    t.ok(Injector.DEFAULTS.trial_timeout_ticks > Injector.DEFAULTS.observe_ticks,
         "the trial budget is larger than the observation window alone")
end

do
    local cfg = Injector.config({ observe_ticks = 7 })
    t.eq(cfg.observe_ticks, 7, "an override reaches the config")
    t.eq(cfg.grace_ticks, Injector.DEFAULTS.grace_ticks, "and leaves the rest alone")
    t.eq(Injector.DEFAULTS.observe_ticks, 120, "without changing the defaults")
end

-- --- the mirror, which had no owner ---------------------------------------------

t.group("a direction is mirrored against the side the character is on")

-- SequenceCompiler has no mirror logic and RunnerFsm hands out inject_mask raw,
-- so the program carries whatever bit InputMask gave to "6" - forward only when
-- the character faces right. The Injector applies the mirror at WRITE time,
-- against the rl_dir of the frame the mask is spent on. These pin the behaviour
-- it depends on.

do
    local profile = InputMask.profile_from_provenance(Provenance, measured_register())
    local L, R = profile.dir.LEFT, profile.dir.RIGHT
    t.ok(L ~= nil and R ~= nil, "the profile names both horizontal bits")

    local mirrored = InputMask.mirror(R, false, profile)
    local straight = InputMask.mirror(R, true, profile)
    t.ok(mirrored ~= nil and straight ~= nil, "the mirror answers for both sides")
    t.ok(mirrored ~= straight,
         "and the two sides differ - which is the whole reason this happens at write time")

    -- One side leaves it alone and the other swaps it. Which is which is the
    -- measured polarity's business, not this test's.
    local swapped = (mirrored == L) or (straight == L)
    t.ok(swapped, "the direction bit is swapped on exactly one of the two sides")
end

do
    -- A profile the mirror cannot read is refused rather than guessed at. The
    -- write path treats nil as "do not write", because a direction written
    -- against an unknown polarity comes out backwards half the time.
    local nope, why = InputMask.mirror(4, true, nil)
    t.is_nil(nope, "no profile, no mirror")
    t.ok(why ~= nil, "and a reason: " .. tostring(why))
end

-- --- lifecycle ------------------------------------------------------------------

t.group("one trial at a time, and nothing parked after it")

do
    t.eq(Injector.running(), false, "nothing is running to begin with")
    t.is_nil(Injector.progress(), "so there is no progress to report")
    t.is_nil(Injector.result(), "and no result")
    t.is_nil(Injector.tick(), "and a tick does nothing")

    local rec, why = Injector.record(nil)
    t.is_nil(rec, "and there is nothing to record")
    t.ok(tostring(why):find("no trial") ~= nil, "which it says: " .. tostring(why))
end

do
    -- install() needs the suite's shared callback array. Without it the answer
    -- is a refusal that names what is missing, not a silent no-op: a sweep that
    -- runs while writing nothing would record every pair as not linking.
    local saved = _G._shared_input_post
    _G._shared_input_post = nil
    local ok, why = Injector.install(function() return true end)
    t.eq(ok, false, "with no shared input array, install fails")
    t.ok(tostring(why):find("_shared_input_post") ~= nil,
         "naming what is missing: " .. tostring(why))
    t.eq(Injector.install_error(), why, "and the reason is readable afterwards")
    _G._shared_input_post = saved
end

return t.finish()
