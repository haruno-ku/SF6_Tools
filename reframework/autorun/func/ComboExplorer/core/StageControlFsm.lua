-- =========================================================
-- ComboExplorer/core/StageControlFsm.lua - resetting the training stage, as a
-- state machine driven one snapshot at a time. Pure: a snapshot in, a command
-- out, no sdk, no sleeping, no callbacks.
-- =========================================================
--
-- A RESET IS NOT A FUNCTION CALL
--
-- Everything about the reset is asynchronous or continuous, and none of it
-- finishes on the frame it is asked for:
--
--   * _IsReqRefresh is a REQUEST. The engine notices it some frames later and
--     clears it when it is done, and nothing bounds how long that takes -
--     upstream polls for it rather than predicting it.
--   * Health, Drive and the SA gauge are servoed back by the engine every
--     frame, so writing them once is writing them to be overwritten. They have
--     to be re-injected on every tick, which is why PIN, SETTLE and READY all
--     keep emitting the same pin command.
--   * The position write does not land the first time. Upstream retries it,
--     with a tolerance, up to a budget.
--   * The combo counter goes on reading the previous trial for some frames
--     after the reset.
--
-- So "reset, then start the trial on the next frame" is not a thing that can be
-- written. The reset is a sequence of states, each of which is left because a
-- SNAPSHOT said so, and the caller ticks it once per frame.
--
-- WHY WAIT_REFRESH MUST NOT EMIT AN INPUT
--
-- An input written while the stage is refreshing is swallowed. Not rejected -
-- swallowed. The move never comes out, the trial observes nothing, and the pair
-- is recorded as "these moves do not link": a confident negative with no error
-- anywhere. Every command therefore carries inject_allowed, and it is true in
-- exactly one state.
--
-- WHY A FLAG THAT READS false IS NOT PROOF THE REFRESH IS DONE
--
-- One tick after the request is written, _IsReqRefresh reads false because the
-- engine has not looked at it yet, not because the refresh has finished.
-- Believing that falling edge starts the trial into a stage that is about to be
-- torn down underneath it. So WAIT_REFRESH waits to SEE the flag high before it
-- will believe it going low, and reports a request that was never observed as a
-- failed reset rather than as a finished one.
--
-- Likewise `refreshing == false` is written out in full everywhere below. A nil
-- means the flag could not be read, which is a different fact, and `not
-- refreshing` would quietly turn one into the other.
--
-- THE TICK COUNTS ARE NOT KNOWN, AND ARE NOT DEFAULTED
--
-- How long settling takes, how long the counter lies for, how close a position
-- write lands and how many retries it needs are all unmeasured on this build.
-- Provenance holds reset_settle_ticks at an unverified 25, arrived at by adding
-- two of upstream's own numbers together. Provenance.value() returns nil until
-- an entry is verified, so a caller wiring these up from the register hands
-- this module nil - and new() refuses. A default here would turn that refusal
-- into a plausible-looking run whose every row was measured against a stage
-- that had not settled.
--
-- ABANDONED IS NOT FAILED
--
-- The game raises _IsReqRefresh on its own. If it rises again after this
-- machine has seen it clear, the stage is being reset underneath a trial that
-- is already in flight: nothing observed after that is evidence about anything,
-- so the trial is ABANDONED and no verdict is recorded. A failed reset is a
-- different fact - the reset was attempted and would not converge - and both
-- are different again from a trial that ran and answered no.

local M = { name = "ComboExplorer.StageControlFsm" }

M.STATE = {
    IDLE         = "idle",
    REQUEST      = "request",
    WAIT_REFRESH = "wait_refresh",
    CORRECT      = "correct",
    PIN          = "pin",
    SETTLE       = "settle",
    READY        = "ready",
    FAILED       = "failed",
    ABANDONED    = "abandoned",
}

M.OUTCOME = {
    READY     = "ready",
    FAILED    = "failed",
    ABANDONED = "abandoned",
}

-- Which snapshot field each pin target is verified against. A pin field with no
-- entry here is still written and is reported as unverifiable, because "we
-- wrote it and never checked" and "we wrote it and it held" must not look the
-- same in the log.
M.PIN_FIELDS = {
    attacker_hp    = "attacker_hp",
    victim_hp      = "victim_hp",
    attacker_drive = "attacker_drive",
    attacker_super = "attacker_super",
}

-- --- configuration -----------------------------------------------------------

local function is_whole(v)
    return type(v) == "number" and v >= 0 and math.floor(v) == v
end

local function check_ticks(v)
    if is_whole(v) then return true end
    return false, "a whole number of ticks"
end

local function check_number(v)
    if type(v) == "number" and v >= 0 then return true end
    return false, "a non-negative number"
end

-- `false` is a real answer here and nil is not. false says "known: there is
-- nothing to correct / nothing to pin"; nil says nobody has decided - and this
-- project turns the second into a refusal rather than into the first.
local function check_positions(v)
    if v == false then return true end
    if type(v) == "table" and type(v.attacker) == "number"
        and type(v.victim) == "number" then
        return true
    end
    return false, "{ attacker = <units>, victim = <units> }, or false for none"
end

local function check_pin(v)
    if v == false then return true end
    if type(v) == "table" then return true end
    return false, "a table of resource targets, or false for none"
end

M.REQUIRED = {
    { key = "settle_ticks", check = check_ticks,
      why = "how many CONSECUTIVE ticks the settle conditions must hold. Nobody "
         .. "has measured it; Provenance.reset_settle_ticks is unverified" },
    { key = "grace_ticks", check = check_ticks,
      why = "how long after the refresh clears the combo counter is still "
         .. "reading the previous trial. Unmeasured on this build" },
    { key = "position_tolerance", check = check_number,
      why = "how close a position write has to land to count as landed. "
         .. "Upstream uses 0.5 units, which is its number and not a measurement" },
    { key = "correction_retries", check = check_ticks,
      why = "how many position writes to spend before reporting that the "
         .. "correction did not converge" },
    { key = "refresh_timeout_ticks", check = check_ticks,
      why = "how long to wait for the refresh flag to rise, and then to clear. "
         .. "The refresh is unbounded in the source, so this bound is a policy "
         .. "the caller states rather than a duration anybody knows" },
    { key = "settle_timeout_ticks", check = check_ticks,
      why = "how long the whole correct/pin/settle phase may take before the "
         .. "reset is reported as never having converged" },
    { key = "target_positions", check = check_positions,
      why = "where the two players are being put, or false to say the caller "
         .. "is not correcting position at all" },
    { key = "pin", check = check_pin,
      why = "the resource values re-injected every tick, or false to say "
         .. "nothing is being pinned" },
}

local Fsm = {}
Fsm.__index = Fsm
M.Fsm = Fsm

-- Returns an fsm, or nil and a reason naming EVERY unset value at once. One
-- refusal listing eight missing numbers is worth more than eight runs that each
-- discover one.
function M.new(cfg)
    if type(cfg) ~= "table" then
        return nil, "StageControlFsm needs a configuration table"
    end

    local problems = {}
    for _, req in ipairs(M.REQUIRED) do
        local v = cfg[req.key]
        if v == nil then
            problems[#problems + 1] = ("%s is unset - %s"):format(req.key, req.why)
        else
            local ok, want = req.check(v)
            if not ok then
                problems[#problems + 1] = ("%s is %s, expected %s")
                    :format(req.key, tostring(v), want)
            end
        end
    end
    if #problems > 0 then
        return nil, ("StageControlFsm refuses to start:\n  %s")
            :format(table.concat(problems, "\n  "))
    end

    local f = setmetatable({}, Fsm)
    f.cfg = {}
    for _, req in ipairs(M.REQUIRED) do f.cfg[req.key] = cfg[req.key] end
    -- Relayed verbatim on the REQUEST tick and never interpreted: which menu
    -- fields a reset writes is the caller's business, and inventing them here
    -- would put game knowledge back into a pure module.
    f.cfg.setup = cfg.setup
    f:reset()
    return f
end

function Fsm:reset()
    self.state = M.STATE.IDLE
    self.outcome = nil
    self.reason = nil

    self.ticks = 0
    self.state_ticks = 0
    self.since_cleared = 0
    self.unresolved_ticks = 0

    self.refresh_seen_high = false
    self.refresh_cleared = false
    self.refresh_wait_ticks = 0
    self.refresh_ticks = 0

    self.correction_attempts = 0
    self.position_error = nil
    self.corrected = nil

    self.pinned = nil
    self.unverifiable_pin_fields = nil

    self.settle_run = 0
    self.settle_ticks_taken = 0
    self.ticks_to_ready = nil
end

-- Begins one reset episode. Called again for the next trial: an fsm is reusable
-- and every counter starts from zero, so a settle time is never a running total
-- across trials.
function Fsm:start()
    self:reset()
    self.state = M.STATE.REQUEST
    return self
end

-- --- commands ----------------------------------------------------------------

-- A command names the state that owned this tick, except on the tick a reset
-- finishes, where it names the outcome - that is the news the caller is waiting
-- for. inject_allowed is present on every command, and true in exactly one
-- state, so a caller cannot forget to ask.
local function command(self, state, fields)
    local cmd = {
        state = state,
        outcome = self.outcome,
        reason = self.reason,
        inject_allowed = (state == M.STATE.READY),
        ticks = self.ticks,
    }
    for k, v in pairs(fields or {}) do cmd[k] = v end
    return cmd
end

local function pin_command(self)
    if self.cfg.pin == false then return nil end
    return self.cfg.pin
end

local function finish(self, outcome, reason, state)
    self.outcome = outcome
    self.reason = reason
    self.state = state
    if outcome == M.OUTCOME.READY then
        self.ticks_to_ready = self.ticks
        return command(self, state, { pin_resources = pin_command(self) })
    end
    return command(self, state)
end

local function enter(self, state)
    self.state = state
    self.state_ticks = 0
end

-- --- the conditions ----------------------------------------------------------

-- The worst absolute error against the targets, or nil when a position could
-- not be read. nil is deliberately not 0: an unreadable position is not a
-- position that has converged.
local function position_error(self, snap)
    local target = self.cfg.target_positions
    if target == false then return nil end
    local a, v = snap.attacker_pos, snap.victim_pos
    if type(a) ~= "number" or type(v) ~= "number" then return nil end
    return math.max(math.abs(a - target.attacker), math.abs(v - target.victim))
end

-- Both idle, no combo running, position inside tolerance. Returns true, false,
-- or nil for "a value could not be read" - and the caller treats nil as
-- breaking the run of good ticks, never as settled. Missing information is not
-- a negative answer, but it is not a positive one either.
local function settled(self, snap)
    if snap.attacker_act_st == nil or snap.victim_act_st == nil then return nil end
    if snap.attacker_act_st ~= 0 or snap.victim_act_st ~= 0 then return false end
    if snap.combo_count == nil then return nil end
    if snap.combo_count ~= 0 then return false end

    if self.cfg.target_positions ~= false then
        local err = position_error(self, snap)
        if err == nil then return nil end
        self.position_error = err
        if err > self.cfg.position_tolerance then return false end
    end
    return true
end

-- Does the snapshot read back the values PIN keeps writing? Unknown when a
-- field could not be read, for the same reason as above.
local function pin_holds(self, snap)
    local pin = self.cfg.pin
    if pin == false then return true end
    local unverifiable = nil
    local known = true
    for key, want in pairs(pin) do
        local field = M.PIN_FIELDS[key]
        if field == nil then
            unverifiable = unverifiable or {}
            unverifiable[#unverifiable + 1] = key
        else
            local have = snap[field]
            if have == nil then
                known = nil
            elseif have ~= want then
                self.unverifiable_pin_fields = unverifiable
                return false
            end
        end
    end
    self.unverifiable_pin_fields = unverifiable
    return known
end

-- --- the machine -------------------------------------------------------------

-- snap is the GameAdapter snapshot for this tick plus `refreshing`, which
-- GameAdapter.snapshot() does not carry: it is a training-manager flag, read by
-- GameAdapter.is_refreshing(), and the runtime layer puts the two together.
function Fsm:tick(snap)
    if self.state == M.STATE.IDLE then
        return command(self, M.STATE.IDLE, { reason = "not started" })
    end
    if self.state == M.STATE.FAILED or self.state == M.STATE.ABANDONED then
        return command(self, self.state)
    end

    if type(snap) ~= "table" then
        -- A tick with nothing to read proves nothing. It is counted, and it
        -- does not advance the machine.
        self.unresolved_ticks = self.unresolved_ticks + 1
        return command(self, self.state)
    end

    self.ticks = self.ticks + 1
    self.state_ticks = self.state_ticks + 1

    local refreshing = snap.refreshing
    if refreshing == nil then
        self.unresolved_ticks = self.unresolved_ticks + 1
    end

    -- The watchdog. Once this machine has seen the refresh clear, the flag
    -- going up again is the game resetting the stage on its own, underneath a
    -- trial that may already be running.
    if self.refresh_cleared and refreshing == true then
        return finish(self, M.OUTCOME.ABANDONED,
            "the game raised _IsReqRefresh again after the reset had completed - "
            .. "the stage was reset underneath the trial",
            M.STATE.ABANDONED)
    end

    if self.state == M.STATE.REQUEST then
        return self:_request()
    elseif self.state == M.STATE.WAIT_REFRESH then
        return self:_wait_refresh(refreshing)
    end

    self.since_cleared = self.since_cleared + 1

    -- The three converging states share one bound, so an unreadable snapshot
    -- cannot hold the machine open for ever in any of them. READY is outside
    -- it deliberately: once the stage is reproducible the machine stays there
    -- for as long as the trial runs, and a bound that kept counting would fail
    -- a reset that had already succeeded - reported to the runner as a reset
    -- failure in the middle of an injection.
    if self.state ~= M.STATE.READY
        and self.since_cleared > self.cfg.settle_timeout_ticks then
        return finish(self, M.OUTCOME.FAILED,
            ("the stage did not become reproducible within %d ticks of the "
             .. "refresh clearing (stopped in %s, %d unresolved ticks)")
            :format(self.cfg.settle_timeout_ticks, self.state, self.unresolved_ticks),
            M.STATE.FAILED)
    end

    if self.state == M.STATE.CORRECT then
        return self:_correct(snap)
    elseif self.state == M.STATE.PIN then
        return self:_pin(snap)
    elseif self.state == M.STATE.SETTLE then
        return self:_settle(snap)
    elseif self.state == M.STATE.READY then
        return command(self, M.STATE.READY, { pin_resources = pin_command(self) })
    end

    return command(self, self.state)
end

function Fsm:_request()
    enter(self, M.STATE.WAIT_REFRESH)
    return command(self, M.STATE.REQUEST, {
        write_setup = self.cfg.setup,
        request_refresh = true,
    })
end

function Fsm:_wait_refresh(refreshing)
    -- Nothing is emitted here but the poll. An input written during a refresh
    -- is swallowed and the trial silently produces nothing.
    if not self.refresh_seen_high then
        if refreshing == true then
            self.refresh_seen_high = true
            self.refresh_ticks = 1
            return command(self, M.STATE.WAIT_REFRESH, { polling = "refresh_to_clear" })
        end
        self.refresh_wait_ticks = self.refresh_wait_ticks + 1
        if self.refresh_wait_ticks > self.cfg.refresh_timeout_ticks then
            -- Not "the refresh finished instantly": that is indistinguishable
            -- from "the request never took", and guessing which would start a
            -- trial on a stage nobody reset.
            return finish(self, M.OUTCOME.FAILED,
                ("_IsReqRefresh was requested and never observed high within %d "
                 .. "ticks, so whether the stage was reset at all is unknown")
                :format(self.cfg.refresh_timeout_ticks),
                M.STATE.FAILED)
        end
        return command(self, M.STATE.WAIT_REFRESH, { polling = "refresh_to_rise" })
    end

    if refreshing == false then
        self.refresh_cleared = true
        self.since_cleared = 0
        enter(self, M.STATE.CORRECT)
        return command(self, M.STATE.WAIT_REFRESH, { refresh_cleared = true })
    end

    -- Reached both when the flag stays high and when it cannot be read at all,
    -- so the count of unreadable ticks is part of the reason: "it never
    -- finished" and "we never found out" are different problems with the same
    -- symptom.
    self.refresh_ticks = self.refresh_ticks + 1
    if self.refresh_ticks > self.cfg.refresh_timeout_ticks then
        return finish(self, M.OUTCOME.FAILED,
            ("_IsReqRefresh was not seen to clear in %d ticks (%d of them "
             .. "unreadable)"):format(self.refresh_ticks, self.unresolved_ticks),
            M.STATE.FAILED)
    end
    return command(self, M.STATE.WAIT_REFRESH, { polling = "refresh_to_clear" })
end

function Fsm:_correct(snap)
    if self.cfg.target_positions == false then
        self.corrected = false
        enter(self, M.STATE.PIN)
        return command(self, M.STATE.CORRECT, { corrected = false })
    end

    local err = position_error(self, snap)
    if err ~= nil then
        self.position_error = err
        if err <= self.cfg.position_tolerance then
            self.corrected = true
            enter(self, M.STATE.PIN)
            return command(self, M.STATE.CORRECT, { position_error = err })
        end
    end

    -- The retry cap is spent on WRITES, not on ticks: a tick whose positions
    -- could not be read has tested nothing, and burning a retry on it would
    -- report a correction as having failed that was never attempted.
    if err ~= nil and self.correction_attempts >= self.cfg.correction_retries then
        self.corrected = false
        return finish(self, M.OUTCOME.FAILED,
            ("position correction did not converge: %d writes, still %.4f units "
             .. "out with a tolerance of %.4f")
            :format(self.correction_attempts, err, self.cfg.position_tolerance),
            M.STATE.FAILED)
    end

    if err == nil then
        return command(self, M.STATE.CORRECT, { polling = "position_unreadable" })
    end

    self.correction_attempts = self.correction_attempts + 1
    return command(self, M.STATE.CORRECT, {
        correct_position = {
            attacker = self.cfg.target_positions.attacker,
            victim = self.cfg.target_positions.victim,
        },
        attempt = self.correction_attempts,
        position_error = err,
    })
end

function Fsm:_pin(snap)
    if self.cfg.pin == false then
        self.pinned = false
        enter(self, M.STATE.SETTLE)
        return command(self, M.STATE.PIN, { pinned = false })
    end

    local holds = pin_holds(self, snap)
    if holds == true then
        self.pinned = true
        enter(self, M.STATE.SETTLE)
    end
    -- Emitted whether or not it has taken, and it goes on being emitted in
    -- SETTLE and READY: the engine servos these values back every frame, so a
    -- pin that stops being written stops being true.
    return command(self, M.STATE.PIN, {
        pin_resources = self.cfg.pin,
        pin_holds = holds,
    })
end

function Fsm:_settle(snap)
    self.settle_ticks_taken = self.settle_ticks_taken + 1

    local fields = { pin_resources = pin_command(self) }

    -- Inside the grace the counter can still be reading the previous trial, so
    -- a tick there is not allowed to count towards the run however good it
    -- looks.
    if self.since_cleared <= self.cfg.grace_ticks then
        self.settle_run = 0
        fields.in_grace = true
        return command(self, M.STATE.SETTLE, fields)
    end

    local ok = settled(self, snap)
    if ok == true then
        self.settle_run = self.settle_run + 1
    else
        if ok == nil then self.unresolved_ticks = self.unresolved_ticks + 1 end
        self.settle_run = 0
    end
    fields.settle_run = self.settle_run

    if self.settle_run >= self.cfg.settle_ticks then
        return finish(self, M.OUTCOME.READY, nil, M.STATE.READY)
    end
    return command(self, M.STATE.SETTLE, fields)
end

-- --- reporting ---------------------------------------------------------------

-- Carried into the trial log. A reset that never converged has to be visible as
-- a reset that never converged, rather than as a trial that was merely slow, so
-- the tick counts are reported on every outcome including the failures.
function Fsm:result()
    return {
        outcome = self.outcome,
        state = self.state,
        reason = self.reason,
        ticks_total = self.ticks,
        ticks_to_ready = self.ticks_to_ready,
        refresh_wait_ticks = self.refresh_wait_ticks,
        refresh_ticks = self.refresh_ticks,
        refresh_observed = self.refresh_seen_high,
        settle_ticks_taken = self.settle_ticks_taken,
        settle_run = self.settle_run,
        correction_attempts = self.correction_attempts,
        position_error = self.position_error,
        corrected = self.corrected,
        pinned = self.pinned,
        unverifiable_pin_fields = self.unverifiable_pin_fields,
        unresolved_ticks = self.unresolved_ticks,
        settle_ticks_required = self.cfg.settle_ticks,
        grace_ticks = self.cfg.grace_ticks,
    }
end

function Fsm:is_ready()
    return self.state == M.STATE.READY
end

return M
