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
    local log = { calls = {}, positions = {}, pins = {}, setups = {} }
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
            return answer("request_refresh")
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

return t.finish()
