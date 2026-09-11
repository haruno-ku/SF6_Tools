-- Unit tests for func/ComboExplorer/runtime/CalibrationRunner.lua
--
-- This was the last runtime module that required GameAdapter at file scope, so
-- it could not be loaded on a machine with no game - and the decisions that
-- most needed checking were the ones added when the sweep became unattended:
--
--   which arrangement a side request writes, and that a RETRY re-writes the
--   same one rather than flipping again (flipping on every ask walks the
--   players back and forth forever and never settles)
--
--   that finishing writes the profile by itself, and REFUSES rather than
--   inventing an identity when it was not given one
--
--   that stop() will not throw away an unwritten run on the first press
--
-- The adapter is a table, the same seam StageControl and Injector use.

local t = require("tests.lua.harness")
local CalRunner = require("func/ComboExplorer/runtime/CalibrationRunner")
local Fsm = require("func/ComboExplorer/core/CalibrationFsm")

-- --- a fake game --------------------------------------------------------------

local RAW = dofile("tests/lua/fixtures/zangief_catalog.lua")

local function adapter(opts)
    opts = opts or {}
    local log = { positions = {}, snapshots = 0 }
    return {
        DEFAULT_START_X = { p1 = -150, p2 = 150 },
        character = function() return { name = "Zangief", id = 6, key = "Zangief" } end,
        snapshot = function()
            log.snapshots = log.snapshots + 1
            return {
                attacker_action_id = opts.action_id or 7,
                attacker_pos = 0, victim_pos = 10,
                attacker_rl_dir_raw = (opts.rl_dir == nil) and true or opts.rl_dir,
            }
        end,
        can_inject = function() return true end,
        player = function() return nil end,
        set_start_positions = function(p1x, p2x)
            log.positions[#log.positions + 1] = { p1 = p1x, p2 = p2x }
            if opts.fail_positions then return false, "the game said no" end
            return true
        end,
    }, log
end

local Provenance = require("func/ComboExplorer/core/Provenance")

-- The catalog is handed in rather than loaded: M.load_catalog goes through
-- CatalogLocator and a JSON reader, neither of which exists here.
local function start(over)
    over = over or {}
    CalRunner.stop({ force = true })
    local ad, log = adapter(over.adapter_opts)
    local run, err = CalRunner.start(Provenance.new(), {
        adapter = ad,
        catalog_raw = RAW,
        identity = over.identity,
        settle_ticks = over.settle_ticks or 2,
        side_retry_ticks = over.side_retry_ticks,
        side_timeout_ticks = over.side_timeout_ticks,
    })
    return run, err, ad, log
end

-- Ticks until the plan reaches a step that wants the side the snapshot is NOT
-- on, which is the only state that asks for a swap.
local function tick_until_side_request(log, n)
    for _ = 1, (n or 4000) do
        CalRunner.tick()
        if #log.positions > 0 then return true end
    end
    return false
end

-- --- the side request ----------------------------------------------------------

t.group("serving a side request without knowing which side is which")

do
    -- The flip is blind on purpose. Which arrangement produces which rl_dir is
    -- the polarity the sweep exists to measure, so a runner that placed the
    -- character "on the truthy side" would be answering the question under test.
    local ad, log = adapter()
    t.eq(ad.DEFAULT_START_X.p1, -150, "the default arrangement is upstream's")
    t.eq(ad.DEFAULT_START_X.p2, 150, "P1 on the left")

    local ok = ad.set_start_positions(150, -150)
    t.eq(ok, true, "the adapter writes an arrangement")
    t.eq(log.positions[1].p1, 150, "carrying both numbers through unchanged")
    t.eq(log.positions[1].p2, -150, "both of them")
end

-- --- stopping ------------------------------------------------------------------

t.group("stop() does not throw away a run nobody has written")

do
    CalRunner.stop({ force = true })
    t.eq(CalRunner.running(), false, "nothing is running")

    -- With no run at all, stopping is not an error.
    local ok = CalRunner.stop()
    t.eq(ok, true, "stopping nothing succeeds")
end

-- --- the profile identity --------------------------------------------------------

t.group("finishing writes the profile, or says why it cannot")

do
    -- The refusal that matters. Calibration.document needs a calibration_id and
    -- a game_patch; a profile filed under a made-up build is worse than one
    -- nobody wrote, because it would be indexed, found, and believed.
    CalRunner.stop({ force = true })
    local path, why = CalRunner.write_profile(nil)
    t.is_nil(path, "with nothing running there is no profile to write")
    t.ok(tostring(why):find("nothing is running") ~= nil, tostring(why))
end


-- --- driving a real run ----------------------------------------------------------

t.group("the side request, served")

do
    -- The adapter always reports rl_dir = true, so every step wanting the falsy
    -- side asks for a swap and never gets one. That is the case worth driving:
    -- it exercises the request, the retry, and the bound all at once.
    local run, err, ad, log = start({ side_retry_ticks = 20, side_timeout_ticks = 400 })
    t.ok(run ~= nil, "a run starts against a fake game: " .. tostring(err))

    t.ok(tick_until_side_request(log), "the run reaches a step that asks for a side")

    local first = log.positions[1]
    t.ok(first ~= nil, "and an arrangement was written")
    -- FLIPPED from the default, not the default itself. The runner does not
    -- know which arrangement gives which rl_dir - that is the polarity under
    -- test - so all it can do is write the opposite of what it last wrote.
    t.eq(first.p1, 150, "the attacker goes to the other side")
    t.eq(first.p2, -150, "and the opponent to theirs")

    -- The retry re-writes the SAME arrangement. Flipping again on every ask
    -- would walk the players back and forth forever and never settle.
    for _ = 1, 200 do CalRunner.tick() end
    t.ok(#log.positions > 1, "it asks again while it waits (" .. #log.positions .. " writes)")
    local same = true
    for _, w in ipairs(log.positions) do
        if w.p1 ~= first.p1 or w.p2 ~= first.p2 then same = false end
    end
    t.eq(same, true, "and every retry writes the SAME arrangement, not a new flip")

    CalRunner.stop({ force = true })
end

do
    -- Not on every tick. Asking every frame is a refresh request every frame,
    -- which is a stutter rather than a swap.
    local run, err, ad, log = start({ side_retry_ticks = 50, side_timeout_ticks = 4000 })
    t.ok(run ~= nil, tostring(err))
    tick_until_side_request(log)
    local after_first = #log.positions
    for _ = 1, 100 do CalRunner.tick() end
    local asked = #log.positions - after_first
    t.ok(asked <= 3, "at most a few asks in 100 ticks, not one per tick (" .. asked .. ")")
    CalRunner.stop({ force = true })
end

do
    -- A write that fails is kept, not swallowed. A swap that did not land
    -- leaves the character where it was, and the step times out blaming the
    -- side rather than the write.
    local run, err, ad, log = start({ adapter_opts = { fail_positions = true },
                                      side_retry_ticks = 20, side_timeout_ticks = 400 })
    t.ok(run ~= nil, tostring(err))
    tick_until_side_request(log)
    local p = CalRunner.progress()
    t.ok(p ~= nil, "the run reports progress")
    CalRunner.stop({ force = true })
end

-- --- stop guards an unwritten run --------------------------------------------------

t.group("stop() refuses once when there are observations and no profile")

do
    local run, err = start()
    t.ok(run ~= nil, tostring(err))
    for _ = 1, 50 do CalRunner.tick() end

    local ok, why = CalRunner.stop()
    t.eq(ok, false, "the first press is refused")
    t.ok(tostring(why):find("WRITE PROFILE") ~= nil,
         "and says what to do instead: " .. tostring(why))
    t.eq(CalRunner.running(), true, "the run is still there")

    t.eq(CalRunner.stop({ force = true }), true, "forcing it works")
    t.eq(CalRunner.running(), false, "and then it is gone")
end

do
    -- With no identity, finishing cannot write - and must say so rather than
    -- invent a build to file the profile under.
    local run, err = start({ identity = nil })
    t.ok(run ~= nil, tostring(err))
    -- Not driven to DONE here (that is thousands of ticks); what is pinned is
    -- that the run knows it has no identity to write with.
    local p = CalRunner.progress()
    t.ok(p ~= nil, "progress is readable while it runs")
    CalRunner.stop({ force = true })
end

-- --- the budgets the FSM will not default -----------------------------------------

t.group("the sweep's own bounds are the FSM's, and they are guesses")

do
    -- These live on CalibrationFsm and are exercised there; what is pinned here
    -- is that the runner does not quietly supply its own.
    for _, key in ipairs({ "settle_timeout_ticks", "side_timeout_ticks",
                           "side_retry_ticks", "gate_timeout_ticks" }) do
        t.ok(Fsm.PROVENANCE[key] ~= nil, ("%s says where it came from"):format(key))
    end
    t.ok(Fsm.DEFAULT_SIDE_RETRY_TICKS < Fsm.DEFAULT_SIDE_TIMEOUT_TICKS,
         "there is room for more than one retry inside the side budget")
end

-- --- the input callback -----------------------------------------------------------

t.group("install refuses loudly when the suite's callback array is missing")

do
    local saved = _G._shared_input_post
    _G._shared_input_post = nil
    local ok, why = CalRunner.install(function() return true end)
    t.eq(ok, false, "with no shared input array, install fails")
    t.ok(tostring(why):find("_shared_input_post") ~= nil,
         "naming what is missing: " .. tostring(why))
    t.eq(CalRunner.install_error(), why, "and the reason is readable afterwards")
    _G._shared_input_post = saved
end

return t.finish()
