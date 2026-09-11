-- Unit tests for func/ComboExplorer/core/CalibrationFsm.lua
--
-- The sequencing is where a calibration goes wrong quietly. Reading one step
-- too early records the PREVIOUS input's action id against THIS step, and the
-- result is a complete, plausible, entirely shifted button map - which the
-- register would then accept and the injector would then run on.

local t = require("tests.lua.harness")
local Fsm = require("func/ComboExplorer/core/CalibrationFsm")
local Calibration = require("func/ComboExplorer/core/Calibration")
local Catalog = require("func/ComboExplorer/core/Catalog")

local RAW = dofile("tests/lua/fixtures/zangief_catalog.lua")

local IDLE = 1

local function new_fsm(opts)
    local session = Calibration.new({ catalog = (Catalog.build(RAW)) })
    opts = opts or {}
    opts.session = session
    local f, err = Fsm.new(opts)
    t.ok(f ~= nil, "the machine builds off a session: " .. tostring(err))
    return f, session
end

local function snap(over)
    local s = { action_id = IDLE, own_pos = 0, opponent_pos = 10,
                rl_dir = true, can_inject = true }
    for k, v in pairs(over or {}) do s[k] = v end
    return s
end

-- Drives the NEUTRAL step to completion and stops the moment the plan moves on.
-- Ticking "while the state is settle" would not do: the step after the neutral
-- one starts in settle too, so that runs straight past it into the first hold.
local function finish_neutral(f, id)
    for _ = 1, 400 do
        if Fsm.current_step(f) and Fsm.current_step(f).phase ~= "neutral" then break end
        Fsm.tick(f, snap({ action_id = id or 7 }))
    end
end

-- Ticks until the plan reaches a step of `phase`, feeding idle the whole way.
local function advance_to_phase(f, phase, idle, rl)
    for _ = 1, 20000 do
        local step = Fsm.current_step(f)
        if not step or step.phase == phase then return step end
        local dir = rl
        if dir == nil and step.side then dir = (step.side == "rl_dir_truthy") end
        if dir == nil then dir = true end
        Fsm.tick(f, snap({ action_id = idle or 7, rl_dir = dir }))
    end
end

-- =========================================================
t.group("the neutral step establishes what idle looks like")

do
    local f, session = new_fsm()
    t.eq(Fsm.current_step(f).phase, "neutral", "the machine starts on the neutral step")

    for _ = 1, 20 do Fsm.tick(f, snap({ action_id = 7 })) end
    t.eq(session.neutral_action_id, 7,
         "whatever was up while nothing was pressed is the idle id - it is measured, not assumed")
    t.ok(Fsm.current_step(f).phase ~= "neutral", "and the machine moved on")
end

do
    local f = new_fsm({ settle_ticks = 5 })
    -- The value keeps changing, so it never settles.
    for i = 1, 20 do Fsm.tick(f, snap({ action_id = i })) end
    t.eq(Fsm.current_step(f).phase, "neutral",
         "an action id that will not hold still is not an idle id")
end

-- =========================================================
t.group("a step does not start until the previous move is over")

do
    local f = new_fsm({ settle_ticks = 8 })
    finish_neutral(f)
    t.eq(f.state, "settle", "now settling before the first bit")

    -- The previous move is still up. No mask may be written.
    local wrote = 0
    for _ = 1, 30 do
        local c = Fsm.tick(f, snap({ action_id = 611 }))
        if c.write_mask then wrote = wrote + 1 end
    end
    t.eq(wrote, 0, "nothing is written while a move is still running")
    t.eq(f.state, "settle", "and the machine has not advanced")

    -- Back to idle: after settle_ticks it starts.
    for _ = 1, 8 do Fsm.tick(f, snap({ action_id = 7 })) end
    t.eq(f.state, "hold", "once the stage has been idle long enough, the hold starts")
end

-- =========================================================
t.group("the hold is as long as the plan says, in ticks that counted")

do
    local f = new_fsm({ settle_ticks = 2 })
    finish_neutral(f)
    while f.state == "settle" do Fsm.tick(f, snap({ action_id = 7 })) end

    local step = Fsm.current_step(f)
    t.eq(step.phase, "button_bits", "on a button step")

    local masks = {}
    while f.state == "hold" do
        local c = Fsm.tick(f, snap({ action_id = 7 }))
        if c.write_mask then masks[#masks + 1] = c.write_mask end
    end
    t.eq(#masks, step.hold_ticks, "the mask is written for exactly hold_ticks ticks")
    t.eq(masks[1], step.mask, "and it is the step's own mask")
end

do
    local f = new_fsm({ settle_ticks = 2 })
    finish_neutral(f)
    while f.state == "settle" do Fsm.tick(f, snap({ action_id = 7 })) end

    -- The gate is shut. A mask written now is swallowed, so those ticks must
    -- not count towards the hold.
    local wrote = 0
    for _ = 1, 20 do
        local c = Fsm.tick(f, snap({ action_id = 7, can_inject = false }))
        if c.write_mask then wrote = wrote + 1 end
    end
    t.eq(wrote, 0, "nothing is written while the injection gate is shut")
    t.eq(f.state, "hold", "and the hold has not progressed")
    t.eq(f.gate_shut_ticks, 20, "the skipped ticks are counted, not hidden")
end

-- =========================================================
t.group("what counts as the action it produced")

-- Drives one button step to completion and returns what was recorded.
local function one_button_step(during_hold, during_watch)
    local f, session = new_fsm({ settle_ticks = 2, watch_ticks = 10 })
    finish_neutral(f)
    while f.state == "settle" do Fsm.tick(f, snap({ action_id = 7 })) end
    local step = Fsm.current_step(f)

    while f.state == "hold" do
        Fsm.tick(f, snap({ action_id = during_hold or 7 }))
    end
    local i = 0
    while f.state == "watch" do
        i = i + 1
        local id = during_watch and during_watch[i] or 7
        Fsm.tick(f, snap({ action_id = id }))
    end
    return session.observations[step.id], step
end

do
    -- A short normal is over before release: the id shows up DURING the hold.
    local obs = one_button_step(611, nil)
    t.eq(obs.action_id, 611, "an action that appeared during the hold is the answer")
end

do
    -- Startup: idle during the hold, the move appears a few ticks later.
    local obs = one_button_step(7, { 7, 7, 611, 611, 612, 612 })
    t.eq(obs.action_id, 611,
         "the FIRST non-idle id in the window is taken - a follow-up state later in "
         .. "the same window would otherwise be recorded as the move")
end

do
    local obs = one_button_step(7, nil)
    t.eq(obs.action_id, 7, "a bit that produced nothing records the idle id, which is the finding")
end

-- =========================================================
t.group("sides cannot be scripted, so they are asked for")

do
    local f = new_fsm({ settle_ticks = 2 })
    finish_neutral(f)
    local step = advance_to_phase(f, "direction")
    t.eq(step.phase, "direction", "reached a direction step")

    -- Present the wrong side.
    local want_truthy = (step.side == "rl_dir_truthy")
    local c
    for _ = 1, 5 do c = Fsm.tick(f, snap({ action_id = 7, rl_dir = not want_truthy })) end
    t.eq(c.state, "waiting_for_side", "the machine stops and says which side it needs")
    t.ok(tostring(c.note):find("swap sides") or tostring(c.note):find("waiting for"),
         "in words the operator can act on: " .. tostring(c.note))
    t.is_nil(c.write_mask, "and writes nothing while it waits")

    -- Present the right side.
    for _ = 1, 3 do c = Fsm.tick(f, snap({ action_id = 7, rl_dir = want_truthy })) end
    t.ok(c.state == "settle" or c.state == "hold", "and resumes once the side matches")
end

-- =========================================================
t.group("a direction step records the whole movement")

do
    local f, session = new_fsm({ settle_ticks = 2, watch_ticks = 6 })
    finish_neutral(f)
    local step = advance_to_phase(f, "direction")
    local side_true = (step.side == "rl_dir_truthy")

    local guard = 0
    while f.state ~= "hold" and guard < 6000 do
        guard = guard + 1
        Fsm.tick(f, snap({ action_id = 7, rl_dir = side_true, own_pos = 0 }))
    end
    while f.state == "hold" do
        Fsm.tick(f, snap({ action_id = 9, rl_dir = side_true, own_pos = 0 }))
    end
    -- Still walking after release.
    local pos = 0
    while f.state == "watch" do
        pos = pos + 1
        Fsm.tick(f, snap({ action_id = 9, rl_dir = side_true, own_pos = pos }))
    end

    local obs = session.observations[step.id]
    t.eq(obs.own_pos_before, 0, "the position at the start of the hold")
    t.ok(obs.own_pos_after > 0, "and the position at the end of the window, not at release - "
         .. "a walk started during the hold is still moving afterwards")
    t.eq(obs.opponent_pos, 10, "with the opponent, so forward can be told from backward")
end

-- =========================================================
t.group("progress and completion")

do
    local f = new_fsm({ settle_ticks = 1, watch_ticks = 1 })
    local p = Fsm.progress(f)
    t.eq(p.index, 1, "starts at the first step")
    t.ok(p.total > 1, "of several")
    t.eq(p.done, false, "and is not done")

    -- Run the whole plan with the side always matching whatever is asked.
    local guard = 0
    while f.state ~= "done" and guard < 60000 do
        guard = guard + 1
        local step = Fsm.current_step(f)
        local rl = true
        if step and step.side then rl = (step.side == "rl_dir_truthy") end
        Fsm.tick(f, snap({ action_id = 7, rl_dir = rl }))
    end
    t.eq(f.state, "done", "the plan runs to the end")
    t.eq(Fsm.progress(f).done, true, "and says so")

    local c = Fsm.tick(f, snap())
    t.is_nil(c.write_mask, "ticking a finished machine writes nothing")
end

-- =========================================================
t.group("degenerate input")

do
    local f, err = Fsm.new({})
    t.is_nil(f, "no session, no machine")
    t.ok(err ~= nil, "with a reason")
end

-- --- asking for the other side ------------------------------------------------

t.group("the machine asks for the side instead of only waiting for it")

-- It used to only wait. The header said sides cannot be scripted, and the part
-- that is true is that no INPUT can put the character on the other side without
-- walking past the opponent - which is itself a direction input on the side
-- being tested. But the training menu can, and the suite already does it
-- unattended (TrainingMoveExecution.lua:184-197).
--
-- What must not change is who is believed. The request is a request; the wait
-- still polls rl_dir and only moves when rl_dir agrees.

do
    local f = new_fsm({ settle_ticks = 2 })
    finish_neutral(f)
    local step = advance_to_phase(f, "direction")
    local want_truthy = (step.side == "rl_dir_truthy")

    -- Present the wrong side.
    local c
    for _ = 1, 5 do c = Fsm.tick(f, snap({ action_id = 7, rl_dir = not want_truthy })) end
    t.eq(c.state, "waiting_for_side", "the machine is waiting")

    -- The request came on ENTRY, not on every tick since.
    local entry = nil
    local f2 = new_fsm({ settle_ticks = 2 })
    finish_neutral(f2)
    local step2 = advance_to_phase(f2, "direction")
    local want2 = (step2.side == "rl_dir_truthy")
    entry = Fsm.tick(f2, snap({ action_id = 7, rl_dir = not want2 }))
    t.eq(entry.request_side, step2.side, "the tick that enters the wait asks for the side")
    t.ok(tostring(entry.note):find("asking") ~= nil,
         "and says so: " .. tostring(entry.note))
end

do
    -- NOT every tick. Asking every frame is a refresh request every frame,
    -- which is a stutter rather than a swap.
    local f = new_fsm({ settle_ticks = 2, side_retry_ticks = 10, side_timeout_ticks = 1000 })
    finish_neutral(f)
    local step = advance_to_phase(f, "direction")
    local want = (step.side == "rl_dir_truthy")

    local asks = 0
    for _ = 1, 100 do
        local c = Fsm.tick(f, snap({ action_id = 7, rl_dir = not want }))
        if c.request_side ~= nil then asks = asks + 1 end
    end
    t.ok(asks > 1, "it does ask again while it waits (" .. asks .. ")")
    t.ok(asks < 20, "but nothing like every tick (" .. asks .. " in 100)")
end

do
    -- And when the side does change, it proceeds - on rl_dir, not on having
    -- asked. This is the assertion that keeps the request from becoming a
    -- belief.
    local f = new_fsm({ settle_ticks = 2 })
    finish_neutral(f)
    local step = advance_to_phase(f, "direction")
    local want = (step.side == "rl_dir_truthy")

    for _ = 1, 5 do Fsm.tick(f, snap({ action_id = 7, rl_dir = not want })) end
    local c
    for _ = 1, 3 do c = Fsm.tick(f, snap({ action_id = 7, rl_dir = want })) end
    t.ok(c.state == "settle" or c.state == "hold", "it resumes once rl_dir agrees")
end

-- --- budgets ------------------------------------------------------------------

t.group("a run left alone reports instead of hanging")

-- There were no timeouts at all. A step whose character never returned to idle,
-- a side that never flipped, or a gate that stayed shut waited forever and
-- reported nothing - the worst possible behaviour for something meant to be
-- started and walked away from.

do
    local f, session = new_fsm({ settle_ticks = 2, side_retry_ticks = 10,
                                 side_timeout_ticks = 40 })
    finish_neutral(f)
    local step = advance_to_phase(f, "direction")
    local want = (step.side == "rl_dir_truthy")
    local before = step.id

    local c
    for _ = 1, 100 do
        c = Fsm.tick(f, snap({ action_id = 7, rl_dir = not want }))
        if c.abandoned then break end
    end
    t.eq(c.abandoned, true, "a side that never flips is given up on")
    t.eq(#f.abandoned, 1, "and recorded")
    t.eq(f.abandoned[1].step, before, "naming the step")
    t.ok(tostring(f.abandoned[1].reason):find("never became") ~= nil,
         "and why: " .. tostring(f.abandoned[1].reason))

    -- THE ONE THAT MATTERS. Calibration.conclude tells "the step ran and
    -- produced nothing" from "the step never ran", and a fabricated observation
    -- here would turn a step nobody could perform into a measurement that the
    -- bit does nothing.
    t.is_nil(session.observations[before],
             "and NO observation was recorded for the step that was abandoned")

    -- The run continues. One unreachable direction bit is one entry left
    -- unmeasured, not twenty steps thrown away.
    t.ok(Fsm.current_step(f) == nil or Fsm.current_step(f).id ~= before,
         "the machine moved on to the next step")
end

do
    -- The stage never reads idle.
    local f, session = new_fsm({ settle_ticks = 4, settle_timeout_ticks = 30 })
    finish_neutral(f)
    local step = advance_to_phase(f, "button_bits")
    local before = step.id

    local c, churn = nil, 0
    for _ = 1, 200 do
        churn = churn + 1
        -- Never the idle id, and never the same twice in a row.
        c = Fsm.tick(f, snap({ action_id = 5000 + (churn % 7) }))
        if c.abandoned then break end
    end
    t.eq(c.abandoned, true, "a step that never settles is given up on")
    t.ok(tostring(f.abandoned[1].reason):find("never read idle") ~= nil,
         "saying so: " .. tostring(f.abandoned[1].reason))
    t.is_nil(session.observations[before], "with no observation invented")
end

do
    -- The injection gate never opens.
    local f, session = new_fsm({ settle_ticks = 2, gate_timeout_ticks = 25 })
    finish_neutral(f)
    local step = advance_to_phase(f, "button_bits")
    local before = step.id

    local c
    for _ = 1, 200 do
        c = Fsm.tick(f, snap({ action_id = 7, can_inject = false }))
        if c.abandoned then break end
    end
    t.eq(c.abandoned, true, "a gate that stays shut is given up on")
    t.ok(tostring(f.abandoned[1].reason):find("gate stayed shut") ~= nil,
         "saying so: " .. tostring(f.abandoned[1].reason))
    t.is_nil(session.observations[before], "with no observation invented")
end

do
    -- Budgets are budgets: generous ones do not change the ordinary path.
    local f = new_fsm({ settle_ticks = 2 })
    t.ok(f.settle_timeout_ticks > f.settle_ticks,
         "the settle budget is larger than the settle requirement")
    t.ok(f.side_timeout_ticks > f.side_retry_ticks,
         "and there is room for more than one retry inside the side budget")
    for _, key in ipairs({ "settle_timeout_ticks", "side_timeout_ticks",
                           "side_retry_ticks", "gate_timeout_ticks" }) do
        t.ok(Fsm.PROVENANCE[key] ~= nil, ("%s says where it came from"):format(key))
        t.ok(tostring(Fsm.PROVENANCE[key]):find("guessed") ~= nil,
             ("%s is marked a guess, because it is one"):format(key))
    end
end

return t.finish()
