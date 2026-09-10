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
