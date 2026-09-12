-- =========================================================
-- ComboExplorer/runtime/StageControl.lua - the wire between
-- core/StageControlFsm.lua and Street Fighter 6. Deliberately thin: it reads a
-- snapshot, ticks the machine, and performs whatever writes the machine asked
-- for on that tick. Every decision is upstream of here.
-- =========================================================
--
-- WHY THIS FILE DID NOT EXIST AND THE STATE MACHINE DID
--
-- core/StageControlFsm.lua has been complete and under test since early on. It
-- was also unreachable: nothing in the shipping code required it, and
-- GameAdapter could not carry out a single one of the four commands it emits
-- because it had no set_field call of any kind. A tested reset that cannot be
-- performed is not a reset.
--
-- ONLY WHAT THIS TICK ASKED FOR
--
-- Each command names the writes that belong to THAT tick. request_refresh
-- appears once; correct_position appears on the ticks a correction is being
-- attempted; pin_resources appears on every tick that wants the values held,
-- because the engine servos them back and writing once is writing to be
-- overwritten. So this performs exactly the fields that are present and never
-- remembers a command - re-applying a stale one is how a single reset request
-- becomes a refresh every frame.
--
-- WHY IT WRITES NO INPUT
--
-- Nothing here touches pl_input_new. A reset is not an input, and keeping the
-- two apart is what lets this run before the button map has ever been measured:
-- the Provenance gate covers injection, and a reset injects nothing. That is
-- the whole reason this is worth having on its own - it can be taken to the
-- game before the calibration sweep, and it measures the numbers the sweep does
-- not produce.
--
-- WHAT A FAILED WRITE MEANS
--
-- It is kept, not swallowed. A position write that did not land leaves the
-- stage somewhere other than where the caller believes, the trial runs anyway,
-- and the pair is recorded as not linking - a confident negative with no error
-- anywhere. `write_errors` in the result is that list.
--
-- WHAT A WRITE NOW OBSERVES  (issue #40, build 24176760)
--
-- request_refresh reads the flag back inside the same call as the write, and
-- that readback - not the next tick's poll - is the rising edge of OUR request.
-- The engine's training update runs between two of our on_frame ticks, so by
-- the time the machine polls, a request this suite raised has already been
-- consumed: measured as refresh_observed false and refresh_wait_ticks 601 on
-- every run, on a stage that had demonstrably been reset. This file carries the
-- readback from the tick it was taken on to the tick the machine reads it, and
-- the machine decides what it means.

local Fsm = require("func/ComboExplorer/core/StageControlFsm")

local M = { name = "ComboExplorer.StageControl" }

-- GameAdapter is resolved on first use, not at load.
--
-- It calls sdk.find_type_definition at file scope, so requiring it on a machine
-- with no REFramework throws - and requiring it HERE would make this file
-- unloadable on the machine it is written on, which is where its decisions have
-- to be tested. Every caller that has an adapter passes one and never reaches
-- this; the tests pass a table.
--
-- runtime/CatalogLocator.lua took the same shape for the same reason, and it is
-- what made the module #29 said could only be checked on hardware checkable
-- here instead.
local _adapter = nil
local function default_adapter()
    if _adapter == nil then
        _adapter = require("func/ComboExplorer/runtime/GameAdapter")
    end
    return _adapter
end

local run = nil

-- --- configuration ------------------------------------------------------------

-- StageControlFsm refuses to start with any of its eight settings unset, and
-- the calibration sweep produces none of them. These are what a first run uses,
-- and every one of them is here rather than in the FSM because the FSM is right
-- to refuse a default.
--
-- The distinction that makes this safe to ship before anything is measured:
-- NONE of these decides whether a link works. They are budgets and tolerances,
-- and every one of them fails LOUDLY when it is wrong - a timeout that is too
-- short reports `reset_failed` and names the state it gave up in. Compare a
-- guessed button bit, which presses nothing, produces no move, and records "these
-- moves do not link". The direction of the failure is the whole difference.
--
-- `measured` marks the one value that came from hardware. The rest travel into
-- the artifact under `guessed` so nobody reads them back as findings.
M.DEFAULTS = {
    -- Probe C, on the 2026-08 build: a reset settles in 7-9 ticks, median 7.
    -- The profile carries 9. This is the only number here that was measured.
    settle_ticks = 9,

    -- Upstream's _reset_grace. RunnerFsm.REQUIRED already says of this value
    -- that it is "upstream's number and not a measurement of this build".
    -- Too large costs time; too small believes a combo counter still reading
    -- the previous trial, so the safe direction is up.
    grace_ticks = 15,

    -- false is a real answer and nil is not: false says "known, there is
    -- nothing to correct / nothing to pin". A first reset does neither, which
    -- keeps the first hardware run to one moving part.
    target_positions = false,
    pin = false,

    -- Unused while target_positions is false. Required anyway, so they are
    -- named as unused in the artifact rather than looking like measurements.
    position_tolerance = 0.5,
    correction_retries = 10,

    -- Budgets. Generous on purpose: the cost of too large is waiting, and the
    -- cost of too small is a reset reported as failed when it was only slow.
    refresh_timeout_ticks = 600,
    settle_timeout_ticks = 600,
}

-- Which of the above is a measurement and which is not. Carried into the
-- artifact so a later reader cannot mistake one for the other.
M.PROVENANCE = {
    settle_ticks = "measured: probe C, 7-9 ticks (median 7) on build 24176760",
    grace_ticks = "guessed: upstream _reset_grace, not measured on this build",
    target_positions = "off for this run",
    pin = "off for this run",
    position_tolerance = "unused while target_positions is false",
    correction_retries = "unused while target_positions is false",
    refresh_timeout_ticks = "guessed: a generous budget, fails loudly if short",
    settle_timeout_ticks = "guessed: a generous budget, fails loudly if short",
}

function M.config(over)
    local cfg = {}
    for k, v in pairs(M.DEFAULTS) do cfg[k] = v end
    for k, v in pairs(over or {}) do cfg[k] = v end
    return cfg
end

-- --- performing one tick's commands -------------------------------------------

-- Separated from the tick so a test can drive it with a table adapter and
-- assert exactly which writes a given command produces. Returns the list of
-- writes attempted, the list that failed, and what the writes OBSERVED.
--
-- `cmd` is whatever StageControlFsm returned this tick. A field that is absent
-- is not a write of nil - it is this tick not asking for that write.
--
-- WHY A WRITE NOW RETURNS AN OBSERVATION  (issue #40)
--
-- request_refresh reads _IsReqRefresh back inside the same call as the write.
-- That readback is the rising edge of our own request, and on build 24176760 it
-- is the only place that edge exists: the engine's training update runs between
-- two of our on_frame ticks, so by the next poll the request has already been
-- consumed. Measured: refresh_observed false and refresh_wait_ticks 601 on
-- every run, on a stage that demonstrably had been reset.
--
-- The third return is that readback, so the caller can hand it to the machine
-- on the following tick. GameAdapter also latches it into its own
-- tick_snapshot, which is what makes this work for the Injector - it performs
-- the stage's writes through this function and never sees the return value.
-- This third return is for the callers that drive their own snapshot instead.
function M.perform(cmd, adapter, attacker_index)
    adapter = adapter or default_adapter()
    attacker_index = attacker_index or 0
    local did, failed = {}, {}
    local observed = {}

    local function note(name, ok, reason)
        did[#did + 1] = name
        if not ok then
            failed[#failed + 1] = { write = name, reason = tostring(reason) }
        end
    end

    if type(cmd) ~= "table" then return did, failed, observed end

    -- Order matters and it is the order the machine implies: the setup has to
    -- be in place before the refresh that pushes it, and both before anything
    -- reads the result.
    if cmd.write_setup ~= nil then
        local ok, reason = adapter.write_setup(cmd.write_setup)
        note("write_setup", ok, reason)
    end

    -- Before the refresh, because the refresh is what APPLIES it. Writing
    -- pos.x after the reset loses to the menu's own start positions - measured
    -- on build 24176760 as ten writes that moved nothing while the fighters sat
    -- at the menu's 558.750 / 68.750. See StageControlFsm:_request.
    if type(cmd.set_start_positions) == "table" then
        local t = cmd.set_start_positions
        -- attacker/victim -> p1/p2. The machine speaks in roles because it does
        -- not know which index is playing; this file does.
        local p1 = (attacker_index == 0) and t.attacker or t.victim
        local p2 = (attacker_index == 0) and t.victim or t.attacker
        -- raise_refresh = false: set_start_positions raises _IsReqRefresh
        -- itself, for the calibration sweep which has no separate request. Here
        -- the next write IS that request, and letting this one raise it first
        -- would make the readback report our own flag as somebody else's and
        -- attach a coalesced-refresh caveat to every trial.
        -- An adapter that predates this command is a real case - the Injector
        -- can be handed a hand-rolled one - and it has to be a recorded write
        -- failure rather than a crash inside a hook, where the error is
        -- swallowed and the trial just stops.
        local ok, reason
        if type(adapter.set_start_positions) == "function" then
            ok, reason = adapter.set_start_positions(p1, p2, { raise_refresh = false })
        else
            ok, reason = false, "this adapter cannot write the training menu's "
                .. "start positions, so the reset cannot place the fighters"
        end
        note("set_start_positions", ok, reason)
    end

    if cmd.request_refresh == true then
        local ok, reason, ack = adapter.request_refresh()
        note("request_refresh", ok, reason)
        -- Kept whether the write reported ok or not: a failed write that still
        -- read the flag back high is a different fact from one that did not,
        -- and the machine is the thing entitled to decide which.
        if type(ack) == "table" then observed.refresh_ack = ack end
    end

    if type(cmd.correct_position) == "table" then
        local target = cmd.correct_position
        if type(target.attacker) == "number" then
            local ok, reason = adapter.set_position(attacker_index, target.attacker)
            note("set_position:attacker", ok, reason)
        end
        if type(target.victim) == "number" then
            local ok, reason = adapter.set_position(1 - attacker_index, target.victim)
            note("set_position:victim", ok, reason)
        end
    end

    -- Every tick it is present, not once. The engine writes these back.
    if cmd.pin_resources ~= nil and cmd.pin_resources ~= false then
        local ok, reason = adapter.pin_resources(attacker_index, cmd.pin_resources)
        note("pin_resources", ok, reason)
    end

    return did, failed, observed
end

-- --- the run -------------------------------------------------------------------

-- opts.adapter : substituted by tests. Defaults to GameAdapter.
-- opts.cfg     : overrides on M.DEFAULTS.
-- opts.attacker_index : which side is P1's role here. 0 in every current case.
function M.start(opts)
    opts = opts or {}
    if run then return nil, "a stage reset is already running" end

    local adapter = opts.adapter or default_adapter()
    local cfg = M.config(opts.cfg)

    local fsm, err = Fsm.new(cfg)
    if not fsm then return nil, err end

    run = {
        fsm = fsm,
        cfg = cfg,
        adapter = adapter,
        attacker_index = opts.attacker_index or 0,
        ticks = 0,
        writes = {},
        write_errors = {},
        last_state = nil,
        last_command = nil,
        outcome = nil,
        -- The write-time readback from the last request_refresh, waiting to be
        -- handed to the machine on the next tick. Cleared here so a previous
        -- episode's evidence can never be read as this one's.
        pending_ack = nil,
        refresh_ack = nil,
    }
    fsm:start()
    return true
end

function M.stop() run = nil end
function M.running() return run ~= nil end

-- One battle frame. Driven from Clock.on_frame, which is the anchor Probe B
-- validated - not from the input callback, which is a different clock and the
-- one this build is not allowed to assume things about.
function M.tick()
    if not run then return nil end

    local snap = run.adapter.tick_snapshot(run.attacker_index)
    if not snap then
        -- No players is not a failure of the reset. It is a frame in which
        -- nothing could be read, and the machine is not ticked on it: feeding
        -- it a fabricated snapshot is how "the stage was unreadable" turns into
        -- "the stage was wrong".
        run.unreadable = (run.unreadable or 0) + 1
        return nil
    end

    -- The readback from OUR OWN request write, taken last tick, handed to the
    -- machine now. With the real adapter it is also on the snapshot already -
    -- GameAdapter latches it into tick_snapshot, which is what makes this work
    -- for the Injector, a caller that performs the stage's writes through
    -- perform() and never looks at the return value.
    --
    -- What perform() returned wins where both exist, and they are the same
    -- table in every ordinary case. The latch is adapter-wide state: if a
    -- second machine were ever requesting a refresh on the same frames, the
    -- snapshot could carry ITS readback, while this one provably came from this
    -- run's own write. Attributing a refresh to the request that caused it is
    -- the whole of #40, so it is not given up here either.
    --
    -- Once. A readback is evidence about the frame the request was written on,
    -- and a second delivery would be telling the machine the request had just
    -- been raised again.
    if run.pending_ack ~= nil then snap.refresh_ack = run.pending_ack end
    run.pending_ack = nil
    if snap.refresh_ack ~= nil then run.refresh_ack = snap.refresh_ack end

    run.ticks = run.ticks + 1
    local cmd = run.fsm:tick(snap)
    run.last_command = cmd
    run.last_state = cmd.state

    local did, failed, observed = M.perform(cmd, run.adapter, run.attacker_index)
    run.pending_ack = observed.refresh_ack
    for _, w in ipairs(did) do run.writes[w] = (run.writes[w] or 0) + 1 end
    for _, f in ipairs(failed) do
        f.tick = run.ticks
        run.write_errors[#run.write_errors + 1] = f
    end

    if cmd.outcome ~= nil then run.outcome = cmd.outcome end
    return cmd
end

-- A one-line readout for the panel while it is running.
function M.progress()
    if not run then return nil end
    local cmd = run.last_command or {}
    return {
        ticks = run.ticks,
        state = run.last_state,
        outcome = run.outcome,
        reason = cmd.reason,
        polling = cmd.polling,
        attempt = cmd.attempt,
        position_error = cmd.position_error,
        inject_allowed = cmd.inject_allowed,
        write_errors = #run.write_errors,
        unreadable = run.unreadable or 0,
        -- Shown while it runs because it is the one fact that says whether the
        -- request was ever raised at all. Handed over as the table, not as
        -- `ack and ack.after`, which would collapse a measured false into the
        -- nil that means nobody looked - a reset that never started reading as
        -- a reset nobody has evidence about (#40).
        refresh_ack = run.refresh_ack,
        caveats = cmd.caveats,
    }
end

-- What the run measured, which is the point of running it before the sweep.
--
-- The FSM already counts everything worth knowing; this adds what was written
-- and what the settings were, so the numbers can be read against the guesses
-- that produced them.
function M.result()
    if not run then return nil end
    local fsm_result = run.fsm:result()

    local settings = {}
    for k, v in pairs(run.cfg) do
        settings[k] = { value = v, provenance = M.PROVENANCE[k] or "set by the caller" }
    end

    return {
        outcome = run.outcome,
        ticks = run.ticks,
        unreadable_ticks = run.unreadable or 0,
        stage = fsm_result,
        writes = run.writes,
        write_errors = run.write_errors,
        settings = settings,
        -- What the request write actually saw, as the adapter reported it. The
        -- machine's own copy is in `stage`; this one is here so a run that
        -- ended before the machine ever consumed it - stopped by the operator,
        -- or ended by a failed write - still carries the evidence.
        refresh_ack = run.refresh_ack,
    }
end

return M
