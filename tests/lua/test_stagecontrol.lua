-- Unit tests for func/ComboExplorer/runtime/StageControl.lua
--
-- The reset had a complete, tested state machine and no way to be performed:
-- GameAdapter had no set_field call of any kind, so all four commands
-- StageControlFsm emits went nowhere. This is the file that performs them, and
-- what it decides - which writes belong to which tick, what a failed write
-- means, and what a tick with no readable snapshot is - is all checkable here.
--
-- The adapter is a table. That is the same seam CatalogLocator used, and it is
-- why StageControl resolves GameAdapter lazily instead of requiring it: the
-- real one calls sdk at file scope and cannot be loaded on this machine.

local t = require("tests.lua.harness")
local SC = require("func/ComboExplorer/runtime/StageControl")
local Fsm = require("func/ComboExplorer/core/StageControlFsm")

-- --- a fake game --------------------------------------------------------------

-- Records every call. `fail` names writes that should report a failure, so the
-- difference between "attempted" and "landed" is expressible.
local function adapter(opts)
    opts = opts or {}
    local log = { calls = {}, positions = {}, pins = {}, setups = {}, starts = {} }
    local function record(name)
        log.calls[name] = (log.calls[name] or 0) + 1
    end
    local function answer(name)
        if opts.fail and opts.fail[name] then return false, "the game said no" end
        return true
    end
    return {
        request_refresh = function()
            record("request_refresh")
            local ok, reason = answer("request_refresh")
            -- The third return is the readback the real adapter takes inside
            -- the same call as the write. `opts.ack` is what this fake claims
            -- to have seen; absent means an adapter that reports none, which
            -- is the pre-#40 behaviour and has to go on working.
            return ok, reason, opts.ack
        end,
        set_start_positions = function(p1x, p2x, o)
            record("set_start_positions")
            log.starts[#log.starts + 1] = { p1 = p1x, p2 = p2x, opts = o }
            return answer("set_start_positions")
        end,
        set_position = function(index, x)
            record("set_position")
            log.positions[#log.positions + 1] = { index = index, x = x }
            return answer("set_position")
        end,
        pin_resources = function(index, pin)
            record("pin_resources")
            log.pins[#log.pins + 1] = { index = index, pin = pin }
            return answer("pin_resources")
        end,
        write_setup = function(setup)
            record("write_setup")
            log.setups[#log.setups + 1] = setup
            return answer("write_setup")
        end,
        tick_snapshot = function(index)
            record("tick_snapshot")
            if opts.snapshots then
                log.taken = (log.taken or 0) + 1
                return opts.snapshots[log.taken]
            end
            return nil
        end,
    }, log
end

-- --- one tick's commands ------------------------------------------------------

t.group("a command produces exactly the writes it names")

do
    local a, log = adapter()
    local did, failed = SC.perform({ state = "request", request_refresh = true }, a, 0)
    t.eq(log.calls.request_refresh, 1, "request_refresh is performed")
    t.is_nil(log.calls.set_position, "and nothing else is")
    t.is_nil(log.calls.pin_resources, "nothing else at all")
    t.eq_list(did, { "request_refresh" }, "the write is reported")
    t.eq(#failed, 0, "and it landed")
end

do
    -- A field that is absent is not a write of nil, it is this tick not asking.
    -- The trap being tested for: `if cmd.pin_resources then` on a command that
    -- says pin_resources = false, which means "known: nothing to pin".
    local a, log = adapter()
    SC.perform({ state = "pin", pinned = false, pin_resources = false }, a, 0)
    t.is_nil(log.calls.pin_resources, "pin_resources = false writes nothing")

    local a2, log2 = adapter()
    SC.perform({ state = "settle" }, a2, 0)
    t.is_nil(log2.calls.pin_resources, "and an absent field writes nothing either")
    t.is_nil(log2.calls.request_refresh, "on any of the four")
    t.is_nil(log2.calls.set_position, "none of them")
    t.is_nil(log2.calls.write_setup, "none")
end

do
    local a, log = adapter()
    SC.perform({ state = "correct",
                 correct_position = { attacker = -150, victim = 150 } }, a, 0)
    t.eq(log.calls.set_position, 2, "a correction writes both players")
    t.eq(log.positions[1].index, 0, "the attacker is the index it was given")
    t.eq(log.positions[1].x, -150, "at the target the machine named")
    t.eq(log.positions[2].index, 1, "and the victim is the other side")
    t.eq(log.positions[2].x, 150, "at its own target")
end

do
    -- attacker_index is honoured rather than assumed. P1 is 0 in every current
    -- scenario, which is exactly why a hardcoded 0 would never be noticed.
    local a, log = adapter()
    SC.perform({ state = "correct",
                 correct_position = { attacker = -150, victim = 150 } }, a, 1)
    t.eq(log.positions[1].index, 1, "attacker 1 writes player 1")
    t.eq(log.positions[2].index, 0, "and the victim is player 0")
end

do
    local a, log = adapter()
    local pin = { attacker_hp = 10000, victim_hp = 10000 }
    SC.perform({ state = "pin", pin_resources = pin }, a, 0)
    t.eq(log.calls.pin_resources, 1, "a pin command pins")
    t.eq(log.pins[1].pin, pin, "handing the table through untouched")
    t.eq(log.pins[1].index, 0, "for the attacker side")
end

do
    -- A failed write is kept with a reason. Swallowing it leaves the stage
    -- somewhere other than where the caller believes, and the trial runs anyway.
    local a = adapter({ fail = { set_position = true } })
    local did, failed = SC.perform({ state = "correct",
                                     correct_position = { attacker = -150, victim = 150 } }, a, 0)
    t.eq(#did, 2, "both writes were attempted")
    t.eq(#failed, 2, "and both are reported as failed")
    t.eq(failed[1].write, "set_position:attacker", "naming which write")
    t.ok(tostring(failed[1].reason):find("said no") ~= nil,
         "and carrying the reason: " .. tostring(failed[1].reason))
end

do
    -- Nothing here writes an input. A reset is not an input, and that is what
    -- lets this run before the button map has ever been measured.
    local a, log = adapter()
    SC.perform({ state = "ready", inject_allowed = true,
                 pin_resources = { attacker_hp = 1 } }, a, 0)
    t.is_nil(log.calls.write_input, "there is no input write on the adapter at all")
    t.eq(log.calls.pin_resources, 1, "only the writes the reset owns")
end

-- --- the run ------------------------------------------------------------------

t.group("a whole reset, performed")

-- The snapshot shape StageControlFsm reads, plus `refreshing`, which
-- GameAdapter.snapshot does not carry and tick_snapshot adds.
local function snap(over)
    local s = {
        refreshing = false,
        attacker_pos = -150, victim_pos = 150,
        attacker_act_st = 0, victim_act_st = 0,
        combo_count = 0, guard_count = 0,
        attacker_hp = 10000, victim_hp = 10000,
        can_inject = true,
    }
    for k, v in pairs(over or {}) do s[k] = v end
    return s
end

-- One tick of REQUEST, three with the flag high, then clear.
local function ordinary(n)
    local out = {}
    for i = 1, (n or 60) do
        out[i] = snap((i >= 2 and i <= 4) and { refreshing = true } or nil)
    end
    return out
end

do
    SC.stop()
    local a, log = adapter({ snapshots = ordinary() })
    local ok, err = SC.start({ adapter = a })
    t.ok(ok, "a reset starts on the shipped defaults: " .. tostring(err))

    local cmd
    for _ = 1, 60 do
        cmd = SC.tick()
        if cmd and cmd.outcome ~= nil then break end
    end

    t.ok(cmd ~= nil, "the run produced commands")
    t.eq(cmd.outcome, Fsm.OUTCOME.READY, "and reaches READY: " .. tostring(cmd and cmd.reason))

    local res = SC.result()
    t.ok(res.ticks > 0, "the result counts the ticks it took (" .. res.ticks .. ")")
    t.eq(res.outcome, Fsm.OUTCOME.READY, "and carries the outcome")
    t.eq(#res.write_errors, 0, "with no failed writes")
    t.eq(res.writes.request_refresh, 1,
         "the refresh was requested exactly once, not once per tick")
    SC.stop()
end

do
    -- The measurement this run exists to take. Every one of the eight settings
    -- is a guess except settle_ticks, and the artifact has to say which is
    -- which or the next reader takes the budget for a finding.
    SC.stop()
    local a = adapter({ snapshots = ordinary() })
    SC.start({ adapter = a })
    for _ = 1, 60 do
        local c = SC.tick()
        if c and c.outcome ~= nil then break end
    end
    local res = SC.result()

    t.ok(res.settings ~= nil, "the result carries the settings it ran under")
    t.ok(tostring(res.settings.settle_ticks.provenance):find("measured") ~= nil,
         "settle_ticks says it was measured: " .. tostring(res.settings.settle_ticks.provenance))
    t.ok(tostring(res.settings.refresh_timeout_ticks.provenance):find("guessed") ~= nil,
         "and a budget says it was guessed")
    t.ok(tostring(res.settings.position_tolerance.provenance):find("unused") ~= nil,
         "and an unused one says that rather than looking like a measurement")

    -- The FSM's own numbers are what make the guesses measurable next time.
    t.ok(res.stage ~= nil, "the machine's own result is carried through")
    SC.stop()
end

do
    -- A frame with no readable snapshot is not a failed reset. Feeding the
    -- machine a fabricated one is how "the stage was unreadable" turns into
    -- "the stage was wrong".
    SC.stop()
    local a = adapter({ snapshots = {} })
    SC.start({ adapter = a })
    local cmd = SC.tick()
    t.is_nil(cmd, "an unreadable tick produces no command")

    local p = SC.progress()
    t.eq(p.ticks, 0, "and does not advance the machine")
    t.eq(p.unreadable, 1, "but is counted, so a run that never reads says so")
    SC.stop()
end

do
    -- Two resets at once would interleave their writes.
    SC.stop()
    local a = adapter({ snapshots = ordinary() })
    t.ok(SC.start({ adapter = a }), "the first reset starts")
    local second, why = SC.start({ adapter = a })
    t.is_nil(second, "a second one does not")
    t.ok(tostring(why):find("already running") ~= nil, "and says why: " .. tostring(why))
    SC.stop()
    t.eq(SC.running(), false, "stopping clears it")
end

-- --- the write-time readback reaches the machine (issue #40) -------------------

t.group("the readback the request write took is carried to the next tick")

-- The flag is false on every single tick, which is what build 24176760 does for
-- a request this suite raises: the engine's training update runs between two of
-- our on_frame ticks and has already consumed it by the time we poll. Measured
-- on hardware as refresh_observed false and refresh_wait_ticks 601, on a stage
-- that had demonstrably been reset (P1 walked from -150 to 0.150, one RESET
-- ONCE put it back). Nothing here ever polls the flag high, and the reset still
-- has to complete.
local function never_high(n)
    local out = {}
    for i = 1, (n or 60) do out[i] = snap() end
    return out
end

do
    SC.stop()
    local a, log = adapter({ snapshots = never_high(),
                             ack = { before = false, after = true } })
    SC.start({ adapter = a })

    local cmd
    for _ = 1, 60 do
        cmd = SC.tick()
        if cmd and cmd.outcome ~= nil then break end
    end

    t.eq(cmd.outcome, Fsm.OUTCOME.READY,
         "a reset whose flag is never polled high still completes, because the "
         .. "write read it back: " .. tostring(cmd and cmd.reason))
    local res = SC.result()
    t.eq(res.stage.refresh_high_source, "write_readback",
         "and the result says the readback is what saw it")
    t.eq(res.stage.refresh_ack.after, true, "carrying the readback itself")
    t.is_nil(res.stage.caveats, "with nothing left unobserved")
    t.eq(res.writes.request_refresh, 1,
         "the refresh was still requested exactly once, not once per tick")
    t.eq(log.calls.request_refresh, 1, "and the adapter was asked once")
    SC.stop()
end

do
    -- The write did not land. Every snapshot in this run is a perfectly settled
    -- stage sitting at its defaults - judging the reset by its effect would
    -- call it done - and the readback says the request was never raised.
    SC.stop()
    local a = adapter({ snapshots = never_high(),
                        ack = { before = false, after = false } })
    SC.start({ adapter = a })

    local cmd
    for _ = 1, 60 do
        cmd = SC.tick()
        if cmd and cmd.outcome ~= nil then break end
    end

    t.eq(cmd.outcome, Fsm.OUTCOME.FAILED,
         "a request that read back false fails the reset")
    local res = SC.result()
    t.eq(res.ticks, 2, "on the tick after the write, not after the 600-tick budget")
    t.ok(tostring(res.stage.reason):find("never landed") ~= nil,
         "saying the request never landed: " .. tostring(res.stage.reason))
    t.eq(res.refresh_ack.after, false,
         "and the run keeps the readback the adapter reported")
    SC.stop()
end

do
    -- perform() hands the observation back so a caller that drives its own
    -- snapshot can wire it up. The Injector is such a caller.
    local a = adapter({ ack = { before = false, after = true } })
    local did, failed, observed = SC.perform({ state = "request", request_refresh = true }, a, 0)
    t.eq(#did, 1, "the write is still reported")
    t.eq(#failed, 0, "and it landed")
    t.eq(observed.refresh_ack.after, true, "with the readback returned alongside")

    local a2 = adapter({})
    local _, _, obs2 = SC.perform({ state = "request", request_refresh = true }, a2, 0)
    t.is_nil(obs2.refresh_ack,
             "an adapter that reports no readback produces no readback, rather "
             .. "than a fabricated one")

    local _, _, obs3 = SC.perform({ state = "settle" }, a2, 0)
    t.is_nil(obs3.refresh_ack, "and a tick that requested nothing observes nothing")
end

do
    -- One frame's evidence, delivered once. If the shim re-attached it the
    -- machine would keep being told the request had just been raised.
    SC.stop()
    local seen = {}
    local a = adapter({ snapshots = never_high(),
                        ack = { before = false, after = true } })
    local real_snapshot = a.tick_snapshot
    a.tick_snapshot = function(index)
        local s = real_snapshot(index)
        if s then seen[#seen + 1] = s end
        return s
    end
    SC.start({ adapter = a })
    for _ = 1, 6 do SC.tick() end

    t.is_nil(seen[1].refresh_ack,
             "the tick that asks for the refresh has not written it yet")
    t.eq(seen[2].refresh_ack.after, true, "the next tick carries the readback")
    t.is_nil(seen[3].refresh_ack, "and no tick after that does")
    t.is_nil(seen[4].refresh_ack, "none at all")
    SC.stop()
end

do
    -- GameAdapter latches the readback into its own tick_snapshot as well, so
    -- with the real adapter both routes carry it and they are the same table.
    -- Where they disagree, what THIS run's own write returned wins: the latch
    -- is adapter-wide state that another machine requesting a refresh on the
    -- same frames could have written. Attributing a refresh to the request that
    -- caused it is the whole of #40.
    --
    -- The snapshot claims the write landed and this run's own write says it did
    -- not, so which one was believed is visible in the outcome.
    SC.stop()
    local snaps = never_high()
    snaps[2].refresh_ack = { before = false, after = true }
    local a = adapter({ snapshots = snaps, ack = { before = false, after = false } })
    SC.start({ adapter = a })

    local cmd
    for _ = 1, 60 do
        cmd = SC.tick()
        if cmd and cmd.outcome ~= nil then break end
    end
    t.eq(cmd.outcome, Fsm.OUTCOME.FAILED,
         "this run's own write is believed over a readback somebody else latched")
    t.eq(SC.result().stage.refresh_ack.after, false, "and it is the one recorded")
    SC.stop()
end

do
    -- ...and an adapter that reports no readback of its own does NOT fall back
    -- to the latch being empty and inventing one. The snapshot's is used when
    -- there is nothing else, which is the Injector's route.
    SC.stop()
    local snaps = never_high()
    snaps[2].refresh_ack = { before = false, after = true }
    local a = adapter({ snapshots = snaps })
    SC.start({ adapter = a })

    local cmd
    for _ = 1, 60 do
        cmd = SC.tick()
        if cmd and cmd.outcome ~= nil then break end
    end
    t.eq(cmd.outcome, Fsm.OUTCOME.READY,
         "a readback that arrives only on the snapshot still reaches the machine")
    t.eq(SC.result().stage.refresh_high_source, "write_readback",
         "and is what the rising edge was seen by")
    SC.stop()
end

-- --- the settings are not invented --------------------------------------------

t.group("the eight settings the machine refuses to default")

do
    -- StageControlFsm refuses to start with any of them unset, and the
    -- calibration sweep produces none of them. If this file stops supplying one,
    -- the reset stops starting - which is the FSM being right, and worth pinning
    -- so the failure is not mistaken for a hardware problem.
    for _, req in ipairs(Fsm.REQUIRED) do
        t.ok(SC.DEFAULTS[req.key] ~= nil,
             ("the shipped defaults supply %s"):format(req.key))
        t.ok(SC.PROVENANCE[req.key] ~= nil,
             ("and say where %s came from"):format(req.key))
    end

    local cfg = SC.config()
    local fsm, why = Fsm.new(cfg)
    t.ok(fsm ~= nil, "so the machine accepts them: " .. tostring(why))
end

do
    local cfg = SC.config({ settle_ticks = 99 })
    t.eq(cfg.settle_ticks, 99, "an override reaches the config")
    t.eq(cfg.grace_ticks, SC.DEFAULTS.grace_ticks, "and leaves the rest alone")
    t.eq(SC.DEFAULTS.settle_ticks, 9, "without changing the defaults themselves")
end

do
    -- The first run does neither correction nor pinning, which keeps it to one
    -- moving part. `false` is the answer that says so; nil would be refused.
    t.eq(SC.DEFAULTS.target_positions, false, "no position correction by default")
    t.eq(SC.DEFAULTS.pin, false, "and nothing pinned")

    local a, log = adapter({ snapshots = ordinary() })
    SC.stop()
    SC.start({ adapter = a })
    for _ = 1, 60 do
        local c = SC.tick()
        if c and c.outcome ~= nil then break end
    end
    t.is_nil(log.calls.set_position, "so no position is written")
    t.is_nil(log.calls.pin_resources, "and nothing is pinned")
    SC.stop()
end


-- --- the reset places the fighters ------------------------------------------

t.group("the positions are asked for BEFORE the refresh, not written after it")

-- Measured on build 24176760: CORRECT's direct pos.x writes never stuck - ten
-- writes, still 603.7500 units out, every trial - because a refresh applies the
-- TRAINING MENU's start positions and the fighters went back to the 558.750 /
-- 68.750 the calibration sweep's side swap had left there. The write mechanism
-- was fine; it was losing to the reset. So the reset is told instead.

do
    local a, log = adapter()
    local did = SC.perform({ state = "request",
                             set_start_positions = { attacker = -45, victim = 45 },
                             request_refresh = true }, a, 0)
    t.eq(#log.starts, 1, "the menu was written once")
    t.eq(log.starts[1].p1, -45, "P1 takes the attacker's x when P1 is the attacker")
    t.eq(log.starts[1].p2, 45, "and P2 the victim's")
    t.eq(log.starts[1].opts.raise_refresh, false,
         "without raising the flag - the request below is that raise, and a "
         .. "flag already high would read back as somebody else's refresh")
    t.eq(did[1], "set_start_positions", "and it happens BEFORE the request")
    t.eq(did[2], "request_refresh", "which is the write that applies it")
end

do
    -- Roles, not indices. The machine does not know which side is playing.
    local a, log = adapter()
    SC.perform({ state = "request",
                 set_start_positions = { attacker = -45, victim = 45 } }, a, 1)
    t.eq(log.starts[1].p1, 45, "with P2 attacking, P1 takes the victim's x")
    t.eq(log.starts[1].p2, -45, "and P2 the attacker's")
end

do
    -- Absent is not a write of nil.
    local a, log = adapter()
    SC.perform({ state = "request", request_refresh = true }, a, 0)
    t.eq(#log.starts, 0, "a command that does not name it writes nothing")
    t.is_nil(log.calls.set_start_positions, "and the adapter is not called at all")
end

do
    -- An adapter from before this command must fail the write, not throw
    -- inside a hook where the error is swallowed and the trial simply stops.
    local a = adapter()
    a.set_start_positions = nil
    local did, failed = SC.perform({ state = "request",
                                     set_start_positions = { attacker = -45, victim = 45 } }, a, 0)
    t.eq(did[1], "set_start_positions", "it is still reported as attempted")
    t.eq(#failed, 1, "and as failed")
    t.ok(tostring(failed[1].reason):find("start positions") ~= nil,
         "naming what could not be written: " .. tostring(failed[1].reason))
end

return t.finish()
