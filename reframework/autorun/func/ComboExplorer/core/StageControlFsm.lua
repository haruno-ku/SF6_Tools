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
-- WHERE "SEEN HIGH" HAS TO BE TAKEN ON BUILD 24176760  (issue #40)
--
-- All of the above still holds. What was wrong was WHERE the rising edge was
-- looked for. Measured on hardware, build 24176760, 2026-09-11:
--
--   * Every reset this machine asked for reported refresh_observed: false and
--     refresh_wait_ticks: 601 - the timeout, every single time.
--   * The reset HAD happened. P1 walked from -150 to 0.150; one RESET ONCE put
--     it back at -150. The writes work; the observation did not.
--   * The read path is not the problem either. Probe C caught the flag high for
--     all 11 OPERATOR-raised resets, each for exactly one tick
--     (refresh_ticks: min 1, max 1).
--
-- So this was never "a one-tick flag is easy to miss". It is WHOSE request it
-- is. The engine's training update runs between two of our on_frame ticks, so a
-- request raised at the end of tick N has already been consumed and cleared by
-- the time we poll at tick N+1. A request the operator raises is raised inside
-- the engine's own frame and is still up when we next look. Polling can observe
-- every refresh EXCEPT the ones this machine asks for.
--
-- The rising edge is therefore taken in the only place it exists for our own
-- request: immediately after the write, in the same Lua call, before any engine
-- code can run. GameAdapter.request_refresh reads the flag back and reports
-- { before, after }; the runtime hands that to the next snapshot as
-- `refresh_ack` and this module consumes it. after == true IS the rising edge,
-- observed - not a weaker observation than the poll but a stronger one, because
-- nothing else can have raised it in between. A later tick reading false is
-- then the falling edge, and both edges belong to one request that is ours.
--
-- after == false is the case the old code could not tell apart from any of
-- this: no engine code ran between the write and the read, so a flag that is
-- low there was never raised. That is reported as a FAILED reset naming the
-- write, not as a timeout - "it never started" stays distinguishable from "it
-- completed", which is the whole point of the wait.
--
-- WHAT WAS CONSIDERED INSTEAD, AND WHY IT LOST
--
--   * "Judge by the effect - see the positions back at their spawn values."
--     It cannot tell a completed reset from a stage that never moved: on a
--     stage already at its defaults the test reads true before the request is
--     even written, which is exactly the unfalsifiable completion test this is
--     replacing. StageControl also ships target_positions = false, so there is
--     no default to compare against at all. The effect check survives where it
--     belongs - as a CORROBORATOR inside SETTLE, never as the completion test.
--   * "Hook set_IsReqRefresh and catch the engine side."
--     SF6_DistanceViewer.lua:3306 does exactly this and it does fire - for the
--     SETTER. A field write (tm._IsReqRefresh = true, which is what this suite
--     uses everywhere, and #40 measured that going through the setter changes
--     nothing about whether the reset happens) never calls it, so the hook
--     cannot see our request. Whether the engine CLEARS through the setter is
--     unknown and cannot be found out from here. A hook that never fires is
--     indistinguishable from a reset that never happened - the same false
--     negative this issue is about - and it costs a permanent, un-removable
--     second hook on a method a shipping module in this suite already owns.
--
-- WHEN THE EVIDENCE IS INCOMPLETE, THE RESULT SAYS SO
--
-- Two cases reach READY without the full chain of evidence, and both attach a
-- caveat to the result rather than being quietly promoted to a clean ok:
--
--   * the flag was ALREADY high when the request was written (someone else's
--     refresh was in flight and ours was coalesced into it - so the training
--     menu write_setup made this tick may have been read before it was made);
--   * the rising edge came from the poll and not from a readback, so it cannot
--     be attributed to this request rather than to the operator's.
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

    -- The write-time readback and what it decided. `refresh_ack_seen` exists so
    -- the ack is consumed exactly once: it belongs to the tick the request was
    -- written on, and a second look at a later tick would be looking at a
    -- different frame's evidence.
    self.refresh_ack = nil
    self.refresh_ack_seen = false
    self.refresh_high_source = nil
    self.refresh_overlapped = nil
    self.caveats = {}

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

-- Something that was NOT observed, recorded against an outcome that is
-- otherwise fine. A caveat never changes the outcome - it is the difference
-- between "ready" and "ready, and here is the part of the chain of evidence
-- that is missing", which a reader of the artifact has to be able to see.
local function add_caveat(self, text)
    self.caveats[#self.caveats + 1] = text
end

local function caveat_list(self)
    if #self.caveats == 0 then return nil end
    return self.caveats
end

local function finish(self, outcome, reason, state)
    self.outcome = outcome
    self.reason = reason
    self.state = state
    if outcome == M.OUTCOME.READY then
        self.ticks_to_ready = self.ticks
        return command(self, state, { pin_resources = pin_command(self),
                                      caveats = caveat_list(self) })
    end
    return command(self, state, { caveats = caveat_list(self) })
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

-- snap is the GameAdapter snapshot for this tick plus two fields
-- GameAdapter.snapshot() does not carry, because neither is a player read and
-- the runtime layer is what puts them together:
--
--   snap.refreshing   : the _IsReqRefresh flag as it reads NOW, tri-state.
--   snap.refresh_ack  : the readback GameAdapter.request_refresh took in the
--                       same Lua call as the write, { before, after, error },
--                       delivered on the tick AFTER the request (the write
--                       happens when the runtime performs the REQUEST command,
--                       which is after that tick's snapshot was taken). nil
--                       when the runtime reported none - an older or
--                       hand-rolled adapter - in which case this falls back to
--                       polling and says in its result that it did.
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
        return self:_wait_refresh(refreshing, snap.refresh_ack)
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

-- WHY THE POSITIONS ARE ASKED FOR BEFORE THE REFRESH, NOT WRITTEN AFTER IT
--
-- CORRECT writes pos.x directly and polls until it sticks. On build 24176760 it
-- never stuck: 10 writes, still 603.7500 units out, every trial, and the
-- fighters sat at 558.750 / 68.750 afterwards - the same two numbers every
-- time, with P1 on the RIGHT.
--
-- Those two numbers are the TRAINING MENU's start positions, left there by the
-- calibration sweep's side swap. A refresh applies them, so every reset put the
-- fighters back where the menu said and the direct writes were overwritten
-- before the next tick could read them. The mechanism was never broken -
-- SF6_Teleport moves the same objects through the same POS_SETx and reported
-- APPLIED: 184.00000 while this was failing. It was fighting the reset.
--
-- So the reset is TOLD instead. set_start_positions is the entry the suite
-- already had for this, ported from the two upstream copies that agree with
-- each other, and a refresh is what applies it - which is the refresh this tick
-- is about to raise anyway.
--
-- CORRECT still runs and still refuses. It is no longer the mechanism, it is
-- the check: if the menu write did not take, the positions are wrong and the
-- trial must not start on a stage nobody placed.
function Fsm:_request()
    enter(self, M.STATE.WAIT_REFRESH)
    local target = self.cfg.target_positions
    return command(self, M.STATE.REQUEST, {
        write_setup = self.cfg.setup,
        -- Absent, not false, when positions are uncontrolled: this tick is not
        -- asking for that write rather than asking for it with no value.
        set_start_positions = (target ~= false) and {
            attacker = target.attacker, victim = target.victim,
        } or nil,
        request_refresh = true,
    })
end

-- The write-time readback, consumed once, on the first WAIT_REFRESH tick after
-- the request was written. Returns a finishing command when the readback
-- settles the question by itself, and nil when the machine should go on.
--
-- See the header: on build 24176760 this is the only place our own request is
-- ever observable, because the engine consumes it before the next poll.
function Fsm:_consume_ack(ack)
    self.refresh_ack_seen = true
    if type(ack) ~= "table" then return nil end

    self.refresh_ack = { before = ack.before, after = ack.after,
                         wrote = ack.wrote, error = ack.error }

    -- The runtime says it never got as far as writing - no training manager, or
    -- the write threw. There is nothing to wait for, and a 600-tick budget
    -- spent on it would bury the adapter's own reason under a timeout.
    if ack.wrote == false then
        return finish(self, M.OUTCOME.FAILED,
            ("the refresh request was never written: %s - so the stage was not "
             .. "reset and nothing was waited for")
            :format(tostring(ack.error or "the runtime did not say why")),
            M.STATE.FAILED)
    end

    if ack.before == true then
        -- Raising a flag that is already raised is a no-op, so our request was
        -- coalesced into somebody else's refresh. The stage is still being
        -- refreshed - this is not a failure - but the training-menu writes
        -- write_setup made on the REQUEST tick may have been read before they
        -- were written, so the stage that comes back may not be the one asked
        -- for. That is a thing NOT observed, and it travels with the result.
        self.refresh_overlapped = true
        add_caveat(self, "_IsReqRefresh was already high when this request was "
            .. "written, so the refresh that was observed was raised by "
            .. "something else and this request was coalesced into it - any "
            .. "training-menu write made on the same tick may have been read "
            .. "before it was made")
    end

    if ack.after == true then
        -- The rising edge. Taken inside the same Lua call as the write, so no
        -- engine code has run and nothing else can have raised it: this is a
        -- stronger observation than the poll, not a weaker one.
        self.refresh_seen_high = true
        self.refresh_high_source = "write_readback"
        self.refresh_ticks = 1
        return nil
    end

    if ack.after == false then
        -- Nothing ran between the write and this read, so the flag was never
        -- raised at all. "It never started" and "it completed before we looked"
        -- are the two answers the old timeout could not separate; this one is
        -- the first, stated as such.
        return finish(self, M.OUTCOME.FAILED,
            ("_IsReqRefresh read back false in the same call as the write, "
             .. "before any engine code could run - the request never landed "
             .. "and the stage was not reset (the flag read %s before the "
             .. "write%s)")
            :format(tostring(ack.before),
                    ack.error and (", write error: " .. tostring(ack.error)) or ""),
            M.STATE.FAILED)
    end

    -- after == nil: the readback could not be read. That is not a no; it is
    -- nobody having found out, so the poll below still gets its chance and the
    -- timeout reason says which of the two evidences was missing.
    return nil
end

function Fsm:_wait_refresh(refreshing, ack)
    -- Nothing is emitted here but the poll. An input written during a refresh
    -- is swallowed and the trial silently produces nothing.
    if not self.refresh_seen_high and not self.refresh_ack_seen then
        local finished = self:_consume_ack(ack)
        if finished then return finished end
    end

    if not self.refresh_seen_high then
        if refreshing == true then
            self.refresh_seen_high = true
            self.refresh_high_source = "poll"
            self.refresh_ticks = 1
            -- A polled rise is a rise SOMEBODY caused. Without a readback of
            -- our own write there is nothing tying it to this request rather
            -- than to the operator's - which is precisely the confusion #40
            -- measured - so the reset may still finish, and it says so.
            add_caveat(self, ("the refresh was observed by polling rather than "
                .. "by reading back our own write (%s), so it cannot be "
                .. "attributed to this request rather than to one the game or "
                .. "the operator raised")
                :format(self.refresh_ack == nil
                    and "the runtime reported no write-time readback"
                    or "the write-time readback could not be read"))
            return command(self, M.STATE.WAIT_REFRESH, { polling = "refresh_to_clear" })
        end
        self.refresh_wait_ticks = self.refresh_wait_ticks + 1
        if self.refresh_wait_ticks > self.cfg.refresh_timeout_ticks then
            -- Not "the refresh finished instantly": that is indistinguishable
            -- from "the request never took", and guessing which would start a
            -- trial on a stage nobody reset. Which evidence was missing is
            -- named, because "no readback was offered" (a runtime that is not
            -- wired up) and "the readback was unreadable" (a game that would
            -- not answer) are different problems with the same symptom.
            local missing = (self.refresh_ack == nil)
                and "the runtime reported no write-time readback at all, and on "
                 .. "build 24176760 a request this machine raises is consumed "
                 .. "before the next poll can see it"
                or ("the write-time readback could not be read (%s)")
                    :format(tostring(self.refresh_ack.error or "no value"))
            return finish(self, M.OUTCOME.FAILED,
                ("_IsReqRefresh was requested and never observed high within %d "
                 .. "ticks, so whether the stage was reset at all is unknown: %s")
                :format(self.cfg.refresh_timeout_ticks, missing),
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
        -- "write_readback" | "poll" | nil. The two are not equivalent evidence
        -- and a reader of the artifact has to be able to tell which one a run
        -- rested on - see the header.
        refresh_high_source = self.refresh_high_source,
        refresh_ack = self.refresh_ack,
        refresh_overlapped = self.refresh_overlapped,
        -- What was NOT observed on an outcome that is otherwise fine. Never a
        -- substitute for the outcome, always attached to it.
        caveats = caveat_list(self),
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
