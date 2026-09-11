-- =========================================================
-- ComboExplorer/core/CalibrationFsm.lua - running a calibration plan, one
-- snapshot at a time. Pure: a snapshot in, a command out. No sdk, no sleeping,
-- no callbacks.
-- =========================================================
--
-- WHY THE SEQUENCE IS A STATE MACHINE AND NOT A LOOP
--
-- "Hold the bit for three frames and read what came out" is four things that
-- each finish on a frame nobody chose:
--
--   * The previous step's move is still running. Reading during it records the
--     PREVIOUS input's action id against THIS step, which is the one error that
--     produces a complete, plausible, entirely shifted button map.
--   * The action does not appear on the frame the input is written. Startup is
--     several frames, and the id that is up during those frames is still the
--     neutral one.
--   * A short normal is over before a naive "read it later" gets there, so the
--     window has to be watched rather than sampled once.
--   * The injection gate can be shut on any given frame (RuntimeSafety), and a
--     mask written while it is shut is swallowed, not rejected. A hold that
--     counted those frames would hold for less than it says.
--
-- So each step is: wait until the stage is genuinely idle, hold, then watch a
-- window for the FIRST action that is not the idle one.
--
-- WHAT COUNTS AS "THE ACTION IT PRODUCED"
--
-- The first non-idle action id seen inside the watch window, and nothing else.
-- Not the last, not the most common: a move that transitions into a follow-up
-- state would otherwise be recorded under the follow-up's id, and a move that
-- ends before the window does would be recorded as idle.
--
-- SIDES CANNOT BE SCRIPTED WITH AN INPUT - BUT THEY CAN BE ASKED FOR
--
-- The direction steps need both values of rl_dir, and there is no INPUT that
-- puts the character on the other side of the opponent without walking past
-- them, which is itself a direction input on the side being tested. That much
-- is still true, and it is why this machine never tries to walk there.
--
-- What it does now is ask. A step whose side does not match the snapshot puts
-- the machine in WAITING_FOR_SIDE and the command carries `request_side`; the
-- runner writes the training menu's start positions and the engine reassigns
-- rl_dir on the refresh. The wait is unchanged - it still polls rl_dir and goes
-- when it agrees - so if the request has no effect this behaves exactly as it
-- did before, and the operator can still move themselves.
--
-- That asymmetry is the whole reason this is safe: the request can save the
-- operator a step, and it cannot produce a wrong measurement, because nothing
-- downstream believes the request. It believes rl_dir.
--
-- The request is emitted ON ENTRY and then only every `side_retry_ticks`.
-- Emitting it every tick would ask the engine to refresh the stage on every
-- frame, which is not a swap, it is a stutter.

local Calibration = require("func/ComboExplorer/core/Calibration")

local M = { name = "ComboExplorer.CalibrationFsm" }

M.STATE = {
    SETTLE            = "settle",             -- waiting for the previous step to be over
    WAITING_FOR_SIDE  = "waiting_for_side",   -- this step needs the other rl_dir
    HOLD              = "hold",               -- writing the mask
    WATCH             = "watch",              -- released, looking for what came out
    DONE              = "done",
}

-- How long the stage has to read idle before a step may start. A move that has
-- visually finished can still have its id up for a frame or two.
M.DEFAULT_SETTLE_TICKS = 8
-- How long to watch after release. Generous: a slow special's startup plus its
-- active frames, and nothing is lost by watching longer than needed because the
-- FIRST non-idle id is what is taken.
M.DEFAULT_WATCH_TICKS = 45

-- BUDGETS, so that a run left alone reports instead of hanging.
--
-- There were none. A step whose character never returned to idle, a side that
-- never flipped, or a gate that stayed shut waited forever and reported
-- nothing - which is the worst possible behaviour for the thing this is for:
-- start it, walk away, come back.
--
-- StageControlFsm already refuses to start without its two timeouts; this is
-- the same discipline. And like those, these are budgets rather than
-- measurements: too small gives up early and SAYS SO, too large only costs
-- time. Neither can turn into a wrong answer about a button.
--
-- Giving up abandons THE STEP, never the run. One direction bit nobody could
-- reach is one entry left unmeasured; the other twenty steps are still worth
-- having.
M.DEFAULT_SETTLE_TIMEOUT_TICKS = 900   -- 15s: the stage never reads idle
M.DEFAULT_SIDE_TIMEOUT_TICKS   = 900   -- 15s: the side never flipped
M.DEFAULT_SIDE_RETRY_TICKS     = 120   -- 2s between asking again
M.DEFAULT_GATE_TIMEOUT_TICKS   = 1800  -- 30s: injection never became permitted

M.PROVENANCE = {
    settle_timeout_ticks = "guessed: a budget, reports and moves on if short",
    side_timeout_ticks   = "guessed: a budget, reports and moves on if short",
    side_retry_ticks     = "guessed: well above the 7-9 tick reset settle probe C measured",
    gate_timeout_ticks   = "guessed: a budget, reports and moves on if short",
}

-- opts.session      : a Calibration session (its plan is what gets run)
-- opts.settle_ticks : idle ticks required before a step starts
-- opts.watch_ticks  : ticks watched after release
function M.new(opts)
    opts = opts or {}
    local session = opts.session
    if type(session) ~= "table" or type(session.observations) ~= "table" then
        return nil, "CalibrationFsm needs a Calibration session"
    end
    local steps = Calibration.plan(session)
    if #steps == 0 then return nil, "the plan is empty" end

    return setmetatable({
        session = session,
        steps = steps,
        index = 1,
        state = M.STATE.SETTLE,
        settle_ticks = tonumber(opts.settle_ticks) or M.DEFAULT_SETTLE_TICKS,
        watch_ticks = tonumber(opts.watch_ticks) or M.DEFAULT_WATCH_TICKS,

        settle_timeout_ticks = tonumber(opts.settle_timeout_ticks)
            or M.DEFAULT_SETTLE_TIMEOUT_TICKS,
        side_timeout_ticks = tonumber(opts.side_timeout_ticks)
            or M.DEFAULT_SIDE_TIMEOUT_TICKS,
        side_retry_ticks = tonumber(opts.side_retry_ticks)
            or M.DEFAULT_SIDE_RETRY_TICKS,
        gate_timeout_ticks = tonumber(opts.gate_timeout_ticks)
            or M.DEFAULT_GATE_TIMEOUT_TICKS,

        settle_spent = 0,    -- ticks this step has been trying to settle
        side_spent = 0,      -- ticks this step has been waiting for its side
        abandoned = {},      -- steps given up on, with why

        idle_run = 0,        -- consecutive idle ticks seen in SETTLE
        held = 0,            -- ticks the mask has actually been written for
        watched = 0,
        captured = nil,      -- the first non-idle action id of this step
        pos_at_hold = nil,
        gate_shut_ticks = 0, -- ticks skipped because injection was not permitted
    }, { __index = M })
end

function M.current_step(fsm)
    return fsm.steps[fsm.index]
end

-- The idle action id is measured, not assumed: the NEUTRAL step at the head of
-- the plan is what establishes it. Until that step has run, nothing else can
-- tell "the move came out" from "nothing happened", so the machine refuses to
-- leave SETTLE on any later step.
local function idle_id(fsm)
    return fsm.session.neutral_action_id
end

local function side_of(snapshot)
    return snapshot.rl_dir and "rl_dir_truthy" or "rl_dir_falsy"
end

local function finish_step(fsm)
    local step = M.current_step(fsm)
    local obs

    if step.phase == Calibration.PHASE.NEUTRAL then
        -- The neutral step's answer IS whatever was up while nothing was
        -- pressed, so the capture rule does not apply to it.
        obs = { action_id = fsm.idle_seen }
    elseif step.phase == Calibration.PHASE.DIRECTION then
        obs = {
            action_id = fsm.captured,
            own_pos_before = fsm.pos_at_hold and fsm.pos_at_hold.own,
            own_pos_after = fsm.pos_at_release and fsm.pos_at_release.own,
            opponent_pos = fsm.pos_at_hold and fsm.pos_at_hold.opponent,
            rl_dir = fsm.pos_at_hold and fsm.pos_at_hold.rl_dir,
        }
    else
        obs = { action_id = fsm.captured or idle_id(fsm) }
    end

    obs.gate_shut_ticks = fsm.gate_shut_ticks
    Calibration.observe(fsm.session, step.id, obs)

    fsm.index = fsm.index + 1
    fsm.state = (fsm.index > #fsm.steps) and M.STATE.DONE or M.STATE.SETTLE
    fsm.idle_run, fsm.held, fsm.watched = 0, 0, 0
    fsm.captured, fsm.pos_at_hold, fsm.pos_at_release = nil, nil, nil
    fsm.gate_shut_ticks = 0
    fsm.settle_spent, fsm.side_spent = 0, 0
end

-- Give up on THIS step and move to the next one.
--
-- No observation is recorded. That matters: Calibration.conclude distinguishes
-- "the step ran and produced nothing" from "the step never ran", and writing a
-- fabricated observation here would turn a step nobody could perform into a
-- measurement that the bit does nothing.
local function abandon_step(fsm, why)
    local step = M.current_step(fsm)
    fsm.abandoned[#fsm.abandoned + 1] = {
        step = step.id, phase = step.phase, side = step.side,
        direction = step.direction, reason = why,
    }
    fsm.index = fsm.index + 1
    fsm.state = (fsm.index > #fsm.steps) and M.STATE.DONE or M.STATE.SETTLE
    fsm.idle_run, fsm.held, fsm.watched = 0, 0, 0
    fsm.captured, fsm.pos_at_hold, fsm.pos_at_release = nil, nil, nil
    fsm.gate_shut_ticks = 0
    fsm.settle_spent, fsm.side_spent = 0, 0
end

-- One tick.
--
-- snapshot : { action_id, own_pos, opponent_pos, rl_dir, can_inject }
--
-- Returns a command:
--   { write_mask = n | nil, state = "...", step_id = "...", note = "..." }
--
-- write_mask is nil on every tick that is not a HOLD tick. The caller writes it
-- and nothing else; a caller that keeps writing the last mask it saw would turn
-- a three-frame tap into a hold for the length of the watch window.
function M.tick(fsm, snapshot)
    if fsm.state == M.STATE.DONE then
        return { state = M.STATE.DONE, write_mask = nil }
    end
    snapshot = snapshot or {}
    local step = M.current_step(fsm)
    local cmd = { state = fsm.state, step_id = step.id, write_mask = nil }

    -- --- SETTLE ---------------------------------------------------------------
    if fsm.state == M.STATE.SETTLE then
        local is_neutral_step = (step.phase == Calibration.PHASE.NEUTRAL)
        local idle = idle_id(fsm)

        fsm.settle_spent = fsm.settle_spent + 1
        if fsm.settle_spent > fsm.settle_timeout_ticks then
            abandon_step(fsm, ("the stage never read idle for %d ticks in a row within %d")
                :format(fsm.settle_ticks, fsm.settle_timeout_ticks))
            cmd.state = fsm.state
            cmd.note = "gave up settling this step and moved on"
            cmd.abandoned = true
            return cmd
        end

        if is_neutral_step then
            -- Nothing to compare against yet. Idle is whatever is up while the
            -- character is left alone, so this step just needs the value to
            -- stop changing.
            if fsm.idle_seen == snapshot.action_id then
                fsm.idle_run = fsm.idle_run + 1
            else
                fsm.idle_seen = snapshot.action_id
                fsm.idle_run = 1
            end
            if fsm.idle_run >= fsm.settle_ticks then
                finish_step(fsm)
                cmd.note = "idle action id recorded"
            end
            return cmd
        end

        if idle == nil then
            cmd.note = "the neutral step has not run, so nothing can be told from an action id"
            return cmd
        end

        -- A direction step belongs to one side, and the machine cannot get
        -- there on its own.
        if step.side and step.side ~= side_of(snapshot) then
            fsm.state = M.STATE.WAITING_FOR_SIDE
            fsm.side_spent = 0
            cmd.state = fsm.state
            -- Asked for on entry. The runner writes the start positions; the
            -- engine reassigns rl_dir on the refresh; the wait below polls for
            -- it. Nothing here believes the request happened.
            cmd.request_side = step.side
            cmd.note = ("step needs %s, the character is %s - asking for a swap")
                :format(step.side, side_of(snapshot))
            return cmd
        end

        if snapshot.action_id == idle then
            fsm.idle_run = fsm.idle_run + 1
        else
            fsm.idle_run = 0
        end
        if fsm.idle_run >= fsm.settle_ticks then
            fsm.state = M.STATE.HOLD
            fsm.pos_at_hold = { own = snapshot.own_pos, opponent = snapshot.opponent_pos,
                                rl_dir = snapshot.rl_dir }
        end
        return cmd
    end

    -- --- WAITING_FOR_SIDE -----------------------------------------------------
    if fsm.state == M.STATE.WAITING_FOR_SIDE then
        if step.side == side_of(snapshot) then
            fsm.state = M.STATE.SETTLE
            fsm.idle_run = 0
            fsm.settle_spent = 0
            cmd.state = fsm.state
            cmd.note = ("side is now %s"):format(tostring(step.side))
            return cmd
        end

        fsm.side_spent = fsm.side_spent + 1

        if fsm.side_spent >= fsm.side_timeout_ticks then
            abandon_step(fsm, ("the side never became %s within %d ticks")
                :format(tostring(step.side), fsm.side_timeout_ticks))
            cmd.state = fsm.state
            cmd.note = "gave up waiting for the side and moved on"
            cmd.abandoned = true
            return cmd
        end

        -- Asked again, not continuously. Every tick would be a refresh request
        -- every frame, which is a stutter rather than a swap.
        if fsm.side_spent % fsm.side_retry_ticks == 0 then
            cmd.request_side = step.side
        end

        cmd.state = fsm.state
        cmd.note = ("waiting for %s (%d/%d)")
            :format(tostring(step.side), fsm.side_spent, fsm.side_timeout_ticks)
        return cmd
    end

    -- --- HOLD -----------------------------------------------------------------
    if fsm.state == M.STATE.HOLD then
        -- A mask written while the gate is shut is swallowed rather than
        -- refused, so those ticks are not counted towards the hold. Counting
        -- them would hold for less than the plan says and blame the result on
        -- the bit.
        if snapshot.can_inject == false then
            fsm.gate_shut_ticks = fsm.gate_shut_ticks + 1
            if fsm.gate_shut_ticks >= fsm.gate_timeout_ticks then
                abandon_step(fsm, ("the injection gate stayed shut for %d ticks")
                    :format(fsm.gate_timeout_ticks))
                cmd.state = fsm.state
                cmd.note = "gave up on a shut gate and moved on"
                cmd.abandoned = true
                return cmd
            end
            cmd.note = "injection gate shut - not counting this tick"
            return cmd
        end

        cmd.write_mask = step.mask
        -- Carried with the mask, never inferred by the writer. The direction
        -- phase measures what the RAW bit does, so mirroring it there would
        -- feed the provisional polarity into the experiment that measures that
        -- polarity; the action sweep presses player-relative notations and does
        -- need it. Only the plan knows which is which.
        cmd.mirror = step.mirror and true or false
        fsm.held = fsm.held + 1

        -- The action can appear while the input is still held; a three-frame
        -- normal is over before release.
        if fsm.captured == nil and snapshot.action_id ~= nil
            and snapshot.action_id ~= idle_id(fsm) then
            fsm.captured = snapshot.action_id
        end

        if fsm.held >= (step.hold_ticks or 1) then
            fsm.state = M.STATE.WATCH
            fsm.pos_at_release = { own = snapshot.own_pos, opponent = snapshot.opponent_pos }
        end
        return cmd
    end

    -- --- WATCH ----------------------------------------------------------------
    if fsm.state == M.STATE.WATCH then
        fsm.watched = fsm.watched + 1
        if fsm.captured == nil and snapshot.action_id ~= nil
            and snapshot.action_id ~= idle_id(fsm) then
            fsm.captured = snapshot.action_id
        end
        -- Positions keep being taken for as long as the window runs: a walk
        -- started during the hold is still moving after release, and the delta
        -- the direction phase needs is the whole of it.
        fsm.pos_at_release = { own = snapshot.own_pos, opponent = snapshot.opponent_pos }

        if fsm.watched >= fsm.watch_ticks then
            finish_step(fsm)
            cmd.note = fsm.captured and "recorded" or "nothing came out"
        end
        return cmd
    end

    return cmd
end

-- Where the run is, for the panel. Nothing here decides anything.
function M.progress(fsm)
    return {
        state = fsm.state,
        index = math.min(fsm.index, #fsm.steps),
        total = #fsm.steps,
        step_id = fsm.steps[fsm.index] and fsm.steps[fsm.index].id,
        purpose = fsm.steps[fsm.index] and fsm.steps[fsm.index].purpose,
        neutral_action_id = fsm.session.neutral_action_id,
        done = fsm.state == M.STATE.DONE,
    }
end

return M
