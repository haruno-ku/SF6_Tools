-- =========================================================
-- ComboExplorer/core/RunnerFsm.lua - one trial, as a state machine. Pure: it
-- takes a snapshot per tick and returns a command per tick, and the whole
-- sequencing of a trial lives here with no sdk call anywhere.
-- =========================================================
--
-- IDLE -> RESETTING -> INJECTING -> OBSERVING -> JUDGING -> RECORDING -> IDLE
--
-- WHY THE MASKS COME FROM THE PROGRAM
--
-- This module does not know a single button bit and must not learn one.
-- SequenceCompiler has already turned the route and the delay into one mask per
-- tick, refusing to do so at all unless the button map has been measured; the
-- runner's job is to play that array back, one entry per tick, and to say which
-- entry it is playing. A runner that built its own mask would be a second place
-- for a wrong bit to live, and a wrong bit does not raise anything - it presses
-- a button that does not exist and the trial reads as "these moves do not link".
--
-- ATTRIBUTION IS THE BUG THAT LOOKS FINE
--
-- The combo counter is shared between the two moves. If B's action id is seen
-- BEFORE B's input has begun, then whatever it is, it is not B: the program's
-- boundaries say to the tick when B's input starts, and no action can be caused
-- by an input that has not happened. Counting such an observation towards B
-- turns A's second hit into "B linked", and the resulting dataset is wrong in
-- the one way that produces no error and no suspicious-looking row.
--
-- So an observation is attributable to step i only from the tick after
-- steps[i].input_starts_at_tick - the compiler's boundary convention is that
-- step i's masks occupy the ticks (input_starts_at_tick, input_ends_at_tick] -
-- and an id arriving earlier is withheld from the verdict and recorded as
-- withheld. Recorded, not dropped: an expected action id showing up before its
-- input is itself a finding, and it is the sort of thing that turns out to be
-- an autocombo or a mis-mapped id later.
--
-- FOUR OUTCOMES, NOT ONE FAILURE
--
-- No move at all, a blocked move, a whiffed move and the WRONG move are four
-- different facts about a trial and only one of them - the blocked or whiffed
-- one - says anything negative about the link. LinkVerdict already draws those
-- lines, so it draws them here too; this module hands it observations and
-- passes on its verdict rather than re-deriving one.
--
-- WHAT IS NOT A VERDICT
--
-- A reset that would not converge, a stage the game refreshed underneath the
-- trial, and a trial that ran out of its tick budget are not results about the
-- pair of moves. They produce no record at all, and are reported as their own
-- outcomes so the sweep can re-queue them. Writing any of them down as a
-- rejection would be recording missing information as a negative answer, which
-- is the failure this project is built to avoid.
--
-- THE TIMEOUTS ARE NOT GUESSED
--
-- How long to keep watching after the last input, and how long a whole trial
-- may take, are unmeasured. They arrive as configuration and new() refuses
-- without them, for the same reason StageControlFsm refuses without its tick
-- counts.

local LinkVerdict = require("func/ComboExplorer/core/LinkVerdict")
local SequenceCompiler = require("func/ComboExplorer/core/SequenceCompiler")

local M = { name = "ComboExplorer.RunnerFsm" }

M.STATE = {
    IDLE      = "idle",
    RESETTING = "resetting",
    INJECTING = "injecting",
    OBSERVING = "observing",
    JUDGING   = "judging",
    RECORDING = "recording",
}

M.OUTCOME = {
    JUDGED       = "judged",        -- a verdict exists; the record carries it
    RESET_FAILED = "reset_failed",  -- the stage never became reproducible
    ABANDONED    = "abandoned",     -- the stage moved underneath the trial
    TIMEOUT      = "timeout",       -- the trial outlived its tick budget
}

-- The outcomes that produce no record. Spelled out rather than derived from
-- `outcome ~= JUDGED`, so that adding an outcome later forces a decision about
-- which side of this line it falls on.
M.NO_RECORD = {
    [M.OUTCOME.RESET_FAILED] = true,
    [M.OUTCOME.ABANDONED]    = true,
    [M.OUTCOME.TIMEOUT]      = true,
}

local function is_whole(v)
    return type(v) == "number" and v >= 0 and math.floor(v) == v
end

M.REQUIRED = {
    { key = "observe_ticks",
      why = "how long to keep watching after the program's last tick. A hit "
         .. "that lands during a super freeze or a slow knockdown arrives after "
         .. "the pad is already neutral, and nobody has measured how much later" },
    { key = "trial_timeout_ticks",
      why = "the whole trial's tick budget, reset included. Without it a stage "
         .. "that never settles hangs the sweep instead of reporting itself" },
    { key = "grace_ticks",
      why = "how long after the reset the combo counter is still reading the "
         .. "previous trial. Handed to LinkVerdict, which will not believe the "
         .. "counter inside it. Upstream's _reset_grace is 15, which is "
         .. "upstream's number and not a measurement of this build" },
}

local Runner = {}
Runner.__index = Runner
M.Runner = Runner

-- opts.stage : a StageControlFsm (anything with start/tick/result). Injected
--              rather than built here so a test can drive a scripted one, and
--              so the reset policy is the caller's to choose.
function M.new(opts)
    if type(opts) ~= "table" then return nil, "RunnerFsm needs a configuration table" end

    local problems = {}
    for _, req in ipairs(M.REQUIRED) do
        local v = opts[req.key]
        if v == nil then
            problems[#problems + 1] = ("%s is unset - %s"):format(req.key, req.why)
        elseif not is_whole(v) then
            problems[#problems + 1] = ("%s is %s, expected a whole number of ticks")
                :format(req.key, tostring(v))
        end
    end

    local stage = opts.stage
    if type(stage) ~= "table" or type(stage.start) ~= "function"
        or type(stage.tick) ~= "function" or type(stage.result) ~= "function" then
        problems[#problems + 1] = "stage is not a stage control machine "
            .. "(needs start, tick and result)"
    end

    if #problems > 0 then
        return nil, ("RunnerFsm refuses to start:\n  %s")
            :format(table.concat(problems, "\n  "))
    end

    local r = setmetatable({}, Runner)
    r.cfg = {
        observe_ticks = opts.observe_ticks,
        trial_timeout_ticks = opts.trial_timeout_ticks,
        grace_ticks = opts.grace_ticks,
    }
    r.stage = stage
    r.state = M.STATE.IDLE
    r.outcome = nil
    return r
end

-- --- starting one trial ------------------------------------------------------

local function id_list(v)
    if type(v) ~= "table" then return nil, "not a list of action ids" end
    local n = 0
    for _ in pairs(v) do n = n + 1 end
    if n == 0 then return nil, "an empty list of action ids" end
    for i = 1, n do
        if type(v[i]) ~= "number" then return nil, "not a list of action ids" end
    end
    return v
end

local function subject_named(spec)
    if type(spec.subject) == "table" then return true end
    if type(spec.edge_id) == "string" and spec.edge_id ~= "" then return true end
    if type(spec.route_id) == "string" and spec.route_id ~= "" then return true end
    return false
end

-- spec:
--   program    : a SequenceCompiler program. The masks and the boundaries both
--                come from it.
--   expected   : action ids per STEP INDEX, { [1] = {600,601}, [2] = {700} }.
--                Lists, because which id an input produces is itself
--                unverified - the catalog groups 617/618/619 rather than
--                choosing between them.
--   judge_gap  : which gap this trial is asking about. Defaults to the last
--                one: in a route the earlier links were the question of an
--                earlier trial, and the new link is the one at the end.
--   attempt    : 1-based. Repeats are the only thing separating a link that
--                reproduces from one that happened once.
--   edge_id | route_id | subject, provenance, conditions : carried into the
--                record untouched.
--
-- Returns true, or nil and a reason. Refusing to start is not a result: nothing
-- is recorded for a trial that never ran.
function Runner:begin(spec)
    if self.state ~= M.STATE.IDLE then
        return nil, ("a trial is already in flight (%s)"):format(self.state)
    end
    if type(spec) ~= "table" then return nil, "not a trial spec" end

    local program = spec.program
    if type(program) ~= "table" or type(program.raw_inputs) ~= "table"
        or type(program.steps) ~= "table" or not is_whole(program.total_ticks) then
        return nil, "the trial has no compiled program to play"
    end
    if #program.raw_inputs ~= program.total_ticks then
        return nil, ("the program says %d ticks and carries %d masks")
            :format(program.total_ticks, #program.raw_inputs)
    end

    -- Same rule ResultCollector applies to a finished record, applied one stage
    -- earlier: a program KNOWN to have been built from an unmeasured button map
    -- must not be injected. A status that is absent is not this failure -
    -- unknown is not known-bad - and the structural gate against injecting at
    -- all is Provenance's injection capability, which lives at the runtime
    -- layer where the buttons are actually written.
    -- `measured`, not `status`. An unknown status still passes, for the reason
    -- the comment above gives - unknown is not known-bad - but a measurement
    -- that corrected a guess is not a reason to refuse a trial.
    if SequenceCompiler.program_is_measured(program) == false then
        return nil, ("the program was compiled with a %s input profile, so "
            .. "anything it produces is a statement about a guess")
            :format(tostring(program.profile_status))
    end

    local gaps = #program.steps - 1
    if gaps < 1 then return nil, "a trial needs a program with at least two steps" end
    local gap = spec.judge_gap or gaps
    if not is_whole(gap) or gap < 1 or gap > gaps then
        return nil, ("judge_gap %s is outside the %d gaps this program has")
            :format(tostring(spec.judge_gap), gaps)
    end

    local expected = spec.expected
    if type(expected) ~= "table" then
        return nil, "the trial has to say which action ids each step should produce"
    end
    local a_ids, aerr = id_list(expected[gap])
    if not a_ids then
        return nil, ("step %d (move A): %s"):format(gap, tostring(aerr))
    end
    local b_ids, berr = id_list(expected[gap + 1])
    if not b_ids then
        return nil, ("step %d (move B): %s"):format(gap + 1, tostring(berr))
    end

    if not subject_named(spec) then
        return nil, "a trial has to name the edge or the route it is about"
    end
    if type(spec.attempt) ~= "number" or spec.attempt < 1 then
        return nil, "a trial is the Nth attempt at its subject, and N starts at 1"
    end

    -- A budget that cannot cover the program is not a timeout, it is a
    -- guarantee that every trial reports a timeout - and a sweep of those looks
    -- exactly like a sweep of hardware trouble.
    -- One window, and it is this machine's. A program built with a tail has
    -- neutral ticks of its own after the last input, and those would be watched
    -- as part of the program and then `observe_ticks` more on top - while the
    -- evidence row records `observe_ticks` alone. Rather than adding the two and
    -- hoping every reader does the same, a program with a tail is refused: it is
    -- a preview build, and previews are not trials.
    --
    -- `> 0`, not `~= 0`. A program that does not carry the field has not said it
    -- has a tail, and silence is not a reason to refuse anything.
    if type(program.tail_ticks) == "number" and program.tail_ticks > 0 then
        return nil, ("this program carries %d tail ticks of its own; the observation "
            .. "window belongs to the runner, so compile it with tail_ticks = 0")
            :format(program.tail_ticks)
    end

    local floor_ticks = program.total_ticks + self.cfg.observe_ticks
    if self.cfg.trial_timeout_ticks <= floor_ticks then
        return nil, ("the trial budget is %d ticks but the program plus its "
            .. "observation window is already %d, before the reset")
            :format(self.cfg.trial_timeout_ticks, floor_ticks)
    end

    self.spec = spec
    self.program = program
    self.judge_gap = gap

    -- Where each expected id becomes attributable. The EARLIEST step that
    -- expects an id wins, because before that step nothing in the program could
    -- have caused it - and a route that repeats a move legitimately expects the
    -- same id twice.
    self.attributable_from = {}
    for index, ids in pairs(expected) do
        local step = program.steps[index]
        if step and type(ids) == "table" then
            for _, id in ipairs(ids) do
                local at = step.input_starts_at_tick
                local known = self.attributable_from[id]
                if known == nil or at < known then self.attributable_from[id] = at end
            end
        end
    end

    self.trial = LinkVerdict.new({
        expected_a = a_ids,
        expected_b = b_ids,
        grace_ticks = self.cfg.grace_ticks,
    })

    self.ticks = 0
    self.program_tick = 0
    self.observed_ticks = 0
    self.withheld = {}
    self.verdict_result = nil
    self.outcome = nil
    self.reason = nil
    self.stopped_in = nil
    self.record = nil
    self.state = M.STATE.RESETTING
    self.stage:start()
    return true
end

-- --- commands ----------------------------------------------------------------

local function command(self, state, fields)
    local cmd = {
        state = state,
        outcome = self.outcome,
        reason = self.reason,
        ticks = self.ticks,
        program_tick = self.program_tick,
    }
    for k, v in pairs(fields or {}) do cmd[k] = v end
    return cmd
end

-- The runner returns to IDLE the moment a trial ends, so the state a trial
-- STOPPED in is kept separately: "timed out while injecting" and "timed out
-- waiting for the stage" are different problems with the same outcome.
local function finish(self, state, outcome, reason, fields)
    self.outcome = outcome
    self.reason = reason
    self.stopped_in = state
    self.state = M.STATE.IDLE
    return command(self, state, fields)
end

-- --- observing ---------------------------------------------------------------

-- Hands one snapshot to the verdict, withholding an action id that no input has
-- yet asked for. The id is withheld rather than the whole snapshot: the counter
-- readings on that tick are real and belong to whichever move IS in progress.
function Runner:_observe(snap, tick_index)
    if type(snap) ~= "table" then
        self.trial:tick(nil, tick_index)
        return
    end

    local aid = snap.attacker_action_id
    -- Written out rather than as `aid and lookup or nil`: that idiom cannot
    -- return a false, and this project's whole vocabulary depends on false and
    -- nil staying different things.
    local from = nil
    if aid ~= nil then from = self.attributable_from[aid] end

    -- The boundary is exclusive: step i's masks occupy the ticks AFTER
    -- input_starts_at_tick, so an id on that tick itself was produced by an
    -- input that had not been written yet.
    if from ~= nil and tick_index <= from then
        self.withheld[#self.withheld + 1] = {
            tick = tick_index,
            action_id = aid,
            attributable_from_tick = from,
        }
        local copy = {}
        for k, v in pairs(snap) do copy[k] = v end
        copy.attacker_action_id = nil
        self.trial:tick(copy, tick_index)
        return
    end

    self.trial:tick(snap, tick_index)
end

-- The compiler's step list says where each move's input ends; that is the tick
-- the pad stopped asking, which is what the latency figures are measured from.
function Runner:_mark_injected(tick_index)
    local a = self.program.steps[self.judge_gap]
    local b = self.program.steps[self.judge_gap + 1]
    if a and tick_index == a.input_ends_at_tick then
        self.trial:mark_injected("a", tick_index)
    end
    if b and tick_index == b.input_ends_at_tick then
        self.trial:mark_injected("b", tick_index)
    end
end

-- --- the machine -------------------------------------------------------------

function Runner:tick(snap)
    if self.state == M.STATE.IDLE then
        return command(self, M.STATE.IDLE, { release = true })
    end

    self.ticks = self.ticks + 1

    -- The stage machine is ticked in EVERY state, not only during the reset. It
    -- is the watchdog for a refresh the game raises on its own, and it is what
    -- keeps re-writing the pinned resources, which the engine servos back every
    -- frame.
    local scmd = self.stage:tick(snap)

    if scmd.outcome == "abandoned" then
        return finish(self, self.state, M.OUTCOME.ABANDONED,
            scmd.reason or "the stage was reset underneath the trial",
            { stage = scmd, release = true })
    end
    if scmd.outcome == "failed" then
        return finish(self, self.state, M.OUTCOME.RESET_FAILED,
            scmd.reason or "the stage never became reproducible",
            { stage = scmd, release = true })
    end

    if self.ticks > self.cfg.trial_timeout_ticks then
        return finish(self, self.state, M.OUTCOME.TIMEOUT,
            ("the trial passed its %d tick budget in %s")
                :format(self.cfg.trial_timeout_ticks, self.state),
            { stage = scmd, release = true })
    end

    if self.state == M.STATE.RESETTING then
        return self:_resetting(scmd)
    elseif self.state == M.STATE.INJECTING then
        return self:_injecting(snap, scmd)
    elseif self.state == M.STATE.OBSERVING then
        return self:_observing(snap, scmd)
    elseif self.state == M.STATE.JUDGING then
        return self:_judging(scmd)
    elseif self.state == M.STATE.RECORDING then
        return self:_recording(scmd)
    end

    return command(self, self.state, { stage = scmd })
end

function Runner:_resetting(scmd)
    -- No mask leaves this state under any circumstances. An input during a
    -- stage refresh is swallowed, and a swallowed input is a trial that
    -- silently produces nothing and reads as a failed link.
    if scmd.outcome == "ready" then
        self.state = M.STATE.INJECTING
    end
    return command(self, M.STATE.RESETTING, { stage = scmd, release = true })
end

function Runner:_injecting(snap, scmd)
    -- Injection begins on the tick AFTER the stage first reports ready:
    -- readiness is a statement about the snapshot just read, and this tick's
    -- input is decided from it.
    if scmd.inject_allowed ~= true then
        return finish(self, M.STATE.INJECTING, M.OUTCOME.ABANDONED,
            ("the stage withdrew permission to inject at program tick %d")
                :format(self.program_tick + 1),
            { stage = scmd, release = true })
    end
    -- Only a KNOWN-shut gate abandons. nil means RuntimeSafety could not be
    -- asked, which is not the same as being told no.
    if snap ~= nil and snap.can_inject == false then
        return finish(self, M.STATE.INJECTING, M.OUTCOME.ABANDONED,
            ("the injection gate was shut at program tick %d, so the program "
             .. "would have been played with a hole in it")
                :format(self.program_tick + 1),
            { stage = scmd, release = true })
    end

    self.program_tick = self.program_tick + 1
    local i = self.program_tick
    local mask = self.program.raw_inputs[i]

    self:_observe(snap, i)
    self:_mark_injected(i)

    if i >= self.program.total_ticks then
        self.state = M.STATE.OBSERVING
    end
    return command(self, M.STATE.INJECTING, { stage = scmd, inject_mask = mask })
end

function Runner:_observing(snap, scmd)
    self.observed_ticks = self.observed_ticks + 1
    self:_observe(snap, self.program.total_ticks + self.observed_ticks)
    if self.observed_ticks >= self.cfg.observe_ticks then
        self.state = M.STATE.JUDGING
    end
    return command(self, M.STATE.OBSERVING, { stage = scmd, release = true })
end

function Runner:_judging(scmd)
    self.verdict_result = self.trial:result()
    self.state = M.STATE.RECORDING
    return command(self, M.STATE.JUDGING, {
        stage = scmd,
        release = true,
        verdict = self.verdict_result.verdict,
    })
end

function Runner:_recording(scmd)
    self.record = self:record_spec()
    return finish(self, M.STATE.RECORDING, M.OUTCOME.JUDGED,
        self.verdict_result.reason,
        { stage = scmd, release = true, record = self.record,
          verdict = self.verdict_result.verdict })
end

-- --- the record --------------------------------------------------------------

-- A ResultCollector.trial spec, assembled but not validated here: this module
-- does not own the schema, and a record it built itself and then blessed itself
-- would be a second opinion nobody asked for.
function Runner:record_spec()
    local r = self.verdict_result
    if r == nil then return nil end

    local evidence = {}
    for k, v in pairs(r) do evidence[k] = v end
    evidence.judge_gap = self.judge_gap
    evidence.trial_ticks = self.ticks
    evidence.program_ticks = self.program.total_ticks
    evidence.observe_ticks = self.cfg.observe_ticks
    evidence.grace_ticks = self.cfg.grace_ticks
    evidence.stage = self.stage:result()
    -- An expected id that turned up before its own input is kept with the
    -- result. It is the sort of thing that later turns out to be an autocombo,
    -- a shared action id, or a boundary that is off by one - and none of those
    -- can be investigated from a row that dropped it.
    evidence.withheld_action_ids = self.withheld

    local spec = self.spec
    return {
        subject = spec.subject,
        edge_id = spec.edge_id,
        route_id = spec.route_id,
        delays = self.program.delays,
        swept_gap = self.program.swept_gap,
        attempt = spec.attempt,
        verdict = r.verdict,
        reason = r.reason,
        evidence = evidence,
        provenance = spec.provenance,
        character = spec.character or self.program.character,
        control_scheme = spec.control_scheme or self.program.control_scheme,
        conditions = spec.conditions,
        program = self.program,
        recorded_at = spec.recorded_at,
        notes = spec.notes,
    }
end

-- Everything about how the last trial ended, including the ones that produced
-- no record. `record` is nil for those, and `produced_record` says so without
-- the caller having to know which outcomes those are.
function Runner:result()
    return {
        outcome = self.outcome,
        reason = self.reason,
        state = self.state,
        stopped_in = self.stopped_in,
        ticks = self.ticks,
        program_ticks = self.program and self.program.total_ticks or nil,
        program_tick_reached = self.program_tick,
        observed_ticks = self.observed_ticks,
        verdict = self.verdict_result and self.verdict_result.verdict or nil,
        withheld_action_ids = self.withheld,
        produced_record = (self.record ~= nil),
        retryable = (self.outcome ~= nil and M.NO_RECORD[self.outcome] == true),
        record = self.record,
        stage = self.stage:result(),
    }
end

return M
