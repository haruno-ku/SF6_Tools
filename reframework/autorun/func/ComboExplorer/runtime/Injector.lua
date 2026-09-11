-- =========================================================
-- ComboExplorer/runtime/Injector.lua - the wire between core/RunnerFsm.lua and
-- Street Fighter 6. It runs ONE trial: reset the stage, play a compiled tick
-- program into P1, watch what came out, hand the result to the collector.
-- =========================================================
--
-- THIS IS THE ONE THE GATE IS ABOUT
--
-- core/Provenance.lua has carried a capability called INJECTION since the first
-- commit, gated on modern_button_bits, direction_bits and rl_dir_polarity, and
-- `Provenance.can` had never been called from anywhere in the shipping code.
-- This is its first caller. Until those three are measured, this refuses to
-- start - and the refusal names them.
--
-- The calibration sweep writes inputs and is allowed to because it is TESTING
-- the provisional button map rather than using it: a bit that produces no move
-- is a measurement about that bit. Here the map is being used. A wrong bit
-- presses nothing, no move comes out, and the trial is recorded as "these moves
-- do not link" - a confident negative that looks exactly like a real one. That
-- asymmetry is the whole reason the gate exists.
--
-- PARK AND SPEND
--
-- pl_input_new is only live inside the pl_input_sub hook, and the machine is
-- ticked from the frame anchor. So the tick DECIDES a mask and parks it, and
-- the input callback SPENDS it. The callback clears it on the way out: a mask
-- left parked would be written again on the next call, and a two-tick tap would
-- quietly become a hold for the rest of the program. Probe B measured one
-- pl_input_sub call per battle frame over 76,565 frames, so one parked mask is
-- written exactly once.
--
-- Copied deliberately from runtime/CalibrationRunner.lua, which is the only
-- other module that does this. Two writers with different rules would be two
-- chances to get the tap length wrong.
--
-- WHO OWNS THE MIRROR
--
-- Nobody did, and it had to be settled here. SequenceCompiler contains no
-- mirror logic at all and RunnerFsm hands out `inject_mask` raw, so the program
-- carries whatever bit InputMask assigned to "6" - which is forward only when
-- the character happens to face right.
--
-- So the mirror is applied at WRITE time, against the rl_dir of the frame the
-- mask is actually spent on. Not at compile time: a program compiled for one
-- side would be wrong the moment a trial ran after a crossover, and nothing
-- would report it - the move simply would not come out.
--
-- The calibration sweep's direction steps do the opposite on purpose (they set
-- mirror = false, because they are measuring the polarity rather than using
-- it). Here the polarity is known - the gate above guarantees it - and used.

local Provenance      = require("func/ComboExplorer/core/Provenance")
local InputMask       = require("func/ComboExplorer/core/InputMask")
local SequenceCompiler = require("func/ComboExplorer/core/SequenceCompiler")
local RunnerFsm       = require("func/ComboExplorer/core/RunnerFsm")
local StageControlFsm = require("func/ComboExplorer/core/StageControlFsm")
local StageControl    = require("func/ComboExplorer/runtime/StageControl")
local JsonIO          = require("func/ComboExplorer/runtime/JsonIO")

local M = { name = "ComboExplorer.Injector" }

-- Resolved on first use, not at load: GameAdapter calls sdk at file scope, so
-- requiring it here would make this file unloadable on the machine its
-- decisions are tested on. Same shape as StageControl and CatalogLocator.
local _adapter = nil
local function default_adapter()
    if _adapter == nil then
        _adapter = require("func/ComboExplorer/runtime/GameAdapter")
    end
    return _adapter
end

local run = nil
local pending_mask = nil     -- decided by the tick, spent by the input callback
local hooked = false
local install_error = nil

-- --- the tick counts the runner will not default ------------------------------

-- RunnerFsm.REQUIRED refuses to start with any of these unset, and - like
-- StageControlFsm's eight - the calibration sweep produces none of them.
--
-- The same argument applies and it is the reason this is not a violation of the
-- project's one rule: none of these decides whether a link works. They are
-- budgets, and a budget that is wrong fails LOUDLY - `timeout` names the state
-- it gave up in. A guessed BUTTON BIT is the opposite: it presses nothing and
-- the trial reports that the moves do not link.
M.DEFAULTS = {
    -- How long to keep watching after the program's last tick. RunnerFsm's own
    -- REQUIRED entry says why nobody can shorten this from a desk: "a hit that
    -- lands during a super freeze or a slow knockdown arrives after the pad is
    -- already neutral, and nobody has measured how much later".
    observe_ticks = 120,

    -- The whole trial's budget, reset included. Must exceed the program plus
    -- the observation window or every trial times out, and RunnerFsm refuses a
    -- budget that cannot cover them rather than letting a sweep of timeouts
    -- look like a sweep of hardware trouble.
    trial_timeout_ticks = 1800,

    -- How long after the reset the combo counter is still reading the previous
    -- trial. Upstream's _reset_grace is 15; RunnerFsm.REQUIRED already records
    -- that this is upstream's number and not a measurement of this build.
    grace_ticks = 15,
}

M.PROVENANCE = {
    observe_ticks = "guessed: generous, so a late hit is still seen. Unmeasured",
    trial_timeout_ticks = "guessed: a budget. Too small reports timeout, loudly",
    grace_ticks = "guessed: upstream _reset_grace, not measured on this build",
}

function M.config(over)
    local cfg = {}
    for k, v in pairs(M.DEFAULTS) do cfg[k] = v end
    for k, v in pairs(over or {}) do cfg[k] = v end
    return cfg
end

-- --- the input callback --------------------------------------------------------

-- Registered once per script generation, as a table entry on
-- _G._shared_input_post rather than a second sdk.hook - which is what keeps
-- this from being the double registration the runbook forbids.
function M.install(is_current)
    if hooked then return true end
    if type(_G._shared_input_post) ~= "table" then
        install_error = "_G._shared_input_post is missing - SharedHooks did not load, "
            .. "so a trial cannot write anything"
        return false, install_error
    end

    table.insert(_G._shared_input_post, function(p_id, _retval)
        if not is_current() then return end
        if p_id ~= 0 then return end

        local mask = pending_mask
        -- Spent. Not left for the next call to find.
        pending_mask = nil

        if not mask or mask == 0 then return end
        if not run then return end

        local p1 = default_adapter().player(0)
        if not p1 then
            run.write_errors = run.write_errors + 1
            return
        end

        local rl = p1:get_field("rl_dir")
        local final, why = InputMask.mirror(mask, rl, run.profile)
        if final == nil then
            -- Refusing is right: a direction written against an unknown
            -- polarity comes out backwards half the time, and a move that came
            -- out backwards is a trial that answers nothing while looking like
            -- it answered no.
            run.write_error = why or "InputMask.mirror refused the profile"
            run.write_errors = run.write_errors + 1
            return
        end

        -- OR, never assign. Every other P1 writer in the suite ORs into
        -- pl_input_new (TrainingMoveExecution.lua:307), and a writer that
        -- assigned would stamp on whatever else is running that frame.
        local now = p1:get_field("pl_input_new") or 0
        p1:set_field("pl_input_new", now | final)
        p1:set_field("pl_sw_new", (p1:get_field("pl_sw_new") or 0) | final)
        run.writes = run.writes + 1
    end)

    hooked = true
    install_error = nil
    return true
end

function M.install_error() return install_error end

-- --- starting one trial ---------------------------------------------------------

-- opts.provenance : the register. The gate is asked of it.
-- opts.route      : a ce.route.v1 - two steps, for a link trial
-- opts.delay      : ticks of neutral between the two moves
-- opts.expected   : action ids per step index, { [1] = {...}, [2] = {...} }
-- opts.subject / edge_id / route_id, opts.attempt
-- opts.allow_injection : the operator's own switch, passed in rather than read
--                        from Config, so this module owes nothing to the panel
-- opts.sink       : { path, dirs } for the JSONL log, or false for no recording
-- opts.adapter    : substituted by tests
function M.start(opts)
    opts = opts or {}
    if run then return nil, "a trial is already running" end

    local reg = opts.provenance
    if type(reg) ~= "table" then return nil, "no provenance register" end

    -- THE GATE. First caller in the project's history.
    local allowed, blockers = Provenance.can(reg, Provenance.CAPABILITY.INJECTION)
    if not allowed then
        local names = {}
        for _, b in ipairs(blockers or {}) do
            names[#names + 1] = tostring(type(b) == "table" and b.key or b)
        end
        return nil, ("injection is blocked until these are measured: %s")
            :format(#names > 0 and table.concat(names, ", ") or "unknown")
    end

    -- The operator's own off switch, after the register rather than instead of
    -- it. Belt and braces: the register is the real gate.
    if opts.allow_injection ~= true then
        return nil, "injection is switched off in the panel"
    end

    -- A consistency check, not a second gate.
    --
    -- Provenance.can(INJECTION) and profile.measured read the same three
    -- entries, so today this cannot fire: if the gate above let us through, the
    -- profile is measured. It is here because the two are computed in different
    -- files by different rules, and the day they stop agreeing the answer must
    -- be a refusal rather than a mask built from a guess.
    --
    -- It is deliberately not covered by a test. There is no register that
    -- passes one and fails the other, so any test of it would have to fake one
    -- of the two - which would be a test of the fake.
    local profile = InputMask.profile_from_provenance(Provenance, reg)
    if not profile then
        return nil, "no input profile could be built from the register"
    end
    if profile.measured ~= true then
        return nil, "the register says injection is available but the profile it "
            .. "produces is not measured - those two disagree, and a mask built "
            .. "from an unmeasured profile presses bits nobody has seen"
    end

    local program, perr = SequenceCompiler.compile(opts.route, {
        profile = profile,
        delay = opts.delay,
        delays = opts.delays,
        -- The observation window belongs to RunnerFsm. A program that brings
        -- its own tail is refused by begin(), and rightly.
        tail_ticks = 0,
    })
    if not program then return nil, "could not compile the route: " .. tostring(perr) end

    -- Checked here, once, rather than per record. A sweep that cannot encode
    -- has to refuse before the first trial, not discover it an hour in with the
    -- results gone.
    local sink, serr = M.open_sink(opts.sink)
    if sink == nil then return nil, serr end

    local cfg = M.config(opts.cfg)
    local stage, staged_err = StageControlFsm.new(StageControl.config(opts.stage_cfg))
    if not stage then return nil, "the stage machine refused: " .. tostring(staged_err) end

    local runner, rerr = RunnerFsm.new({
        stage = stage,
        observe_ticks = cfg.observe_ticks,
        trial_timeout_ticks = cfg.trial_timeout_ticks,
        grace_ticks = cfg.grace_ticks,
    })
    if not runner then return nil, rerr end

    local ok, berr = runner:begin({
        program = program,
        expected = opts.expected,
        -- When this trial started, in wall time.
        --
        -- The field has existed on the record since ResultCollector was written
        -- and nothing ever set it, so every tick number on a trial line was
        -- relative to that trial and reset on the next one: a line could not be
        -- located in anything. That matters now, because the plan for the
        -- published videos is to film verified combos and cut them, and a cut
        -- list has to be anchored to something.
        --
        -- os.date rather than a frame counter: Clock is a runtime module that
        -- calls sdk at file scope, so requiring it here would undo the seam that
        -- makes this file testable. A caller that has the frame counter can pass
        -- opts.frame and it travels alongside.
        recorded_at = opts.recorded_at or os.date("!%Y-%m-%dT%H:%M:%SZ"),
        frame = opts.frame,
        judge_gap = opts.judge_gap,
        attempt = opts.attempt or 1,
        subject = opts.subject,
        edge_id = opts.edge_id,
        route_id = opts.route_id,
        provenance = opts.trial_provenance,
        conditions = opts.conditions,
    })
    if not ok then return nil, berr end

    -- The adapter is reached for LAST, after every refusal above has passed.
    -- Nothing before this point needs the game, and resolving it early made the
    -- gate untestable: a register with nothing measured could not be handed to
    -- start() without also having a Street Fighter to hand it.
    run = {
        runner = runner,
        program = program,
        profile = profile,
        adapter = opts.adapter or default_adapter(),
        cfg = cfg,
        sink = sink,
        attacker_index = opts.attacker_index or 0,
        ticks = 0,
        writes = 0,
        write_errors = 0,
        write_error = nil,
        unreadable = 0,
        outcome = nil,
        last_command = nil,
    }
    pending_mask = nil
    return true
end

-- Returns a sink table, or false for "recording is off", or nil plus a reason.
-- Separate so a test can assert the refusal without a game.
function M.open_sink(spec)
    if spec == false then return false end
    if type(spec) ~= "table" or type(spec.path) ~= "string" then
        return nil, "no sink was given, and a trial whose result is not written "
            .. "is a trial that did not happen"
    end

    local probe, why = JsonIO.encode_line({ schema = "ce.sink_probe.v1", ok = true })
    if not probe then return nil, "the recorder cannot encode: " .. tostring(why) end

    return {
        path = spec.path,
        dirs = spec.dirs,
        append = function(line) return JsonIO.append(spec.path, line, spec.dirs) end,
        encode = JsonIO.encode_line,
    }
end

function M.stop()
    run = nil
    pending_mask = nil
end

function M.running() return run ~= nil end

-- --- one battle frame ------------------------------------------------------------

-- Driven from Clock.on_frame, which is the anchor Probe B validated - NOT from
-- the input callback, which is a different clock and the one this build is not
-- allowed to assume things about.
function M.tick()
    if not run then return nil end

    local snap = run.adapter.tick_snapshot(run.attacker_index)
    if not snap then
        -- A frame nothing could be read on is not a trial that failed. Feeding
        -- the machine a fabricated snapshot is how "unreadable" becomes "the
        -- move did not come out".
        run.unreadable = run.unreadable + 1
        return nil
    end

    run.ticks = run.ticks + 1
    local cmd = run.runner:tick(snap)
    run.last_command = cmd

    -- The stage's writes are performed here, on the runner's own stage command,
    -- rather than by driving StageControl separately: the runner owns the stage
    -- machine, so it owns when the reset happens.
    if type(cmd.stage) == "table" then
        local _, failed = StageControl.perform(cmd.stage, run.adapter, run.attacker_index)
        run.write_errors = run.write_errors + #failed
    end

    -- Park the mask for the input callback. Two conditions, and the second is
    -- deliberately redundant: RunnerFsm emits inject_mask only in INJECTING,
    -- which it can only reach after the stage said READY. Checking
    -- inject_allowed as well costs nothing and the alternative - an input
    -- written while the stage is refreshing - is SWALLOWED rather than
    -- rejected, so the move never comes out and the pair is recorded as not
    -- linking, with no error anywhere.
    local allowed = (cmd.stage == nil) or (cmd.stage.inject_allowed ~= false)
    if cmd.inject_mask ~= nil and allowed then
        pending_mask = cmd.inject_mask
    else
        pending_mask = nil
    end

    if cmd.outcome ~= nil then
        run.outcome = cmd.outcome
        pending_mask = nil
    end
    return cmd
end

-- --- the result -------------------------------------------------------------------

function M.progress()
    if not run then return nil end
    local cmd = run.last_command or {}
    return {
        ticks = run.ticks,
        state = cmd.state,
        program_tick = cmd.program_tick,
        program_ticks = run.program.total_ticks,
        outcome = run.outcome,
        reason = cmd.reason,
        stage_state = type(cmd.stage) == "table" and cmd.stage.state or nil,
        writes = run.writes,
        write_errors = run.write_errors,
        write_error = run.write_error,
        unreadable = run.unreadable,
    }
end

-- The record, handed to the collector the caller gave us. Returns the
-- collector's own report so a refusal is visible rather than assumed.
function M.record(collector)
    if not run then return nil, "no trial to record" end
    if run.outcome == nil then return nil, "the trial has not finished" end

    local spec = run.runner:record_spec()
    if not spec then return nil, "the trial produced no record, which is its answer" end
    if not collector then return spec end

    -- write(), not trial(). M.trial takes ONE argument and only BUILDS a record;
    -- this was calling it with two, so the collector was being validated as if
    -- it were the spec and the record was never appended to anything.
    --
    -- It went unnoticed because the only caller is Sweep, which passes nil to
    -- get the spec and does its own write. The moment anything recorded a trial
    -- through this path it would have silently written nothing.
    local ResultCollector = require("func/ComboExplorer/core/ResultCollector")
    return ResultCollector.write(collector, spec)
end

function M.result()
    if not run then return nil end
    local settings = {}
    for k, v in pairs(run.cfg) do
        settings[k] = { value = v, provenance = M.PROVENANCE[k] or "set by the caller" }
    end
    return {
        outcome = run.outcome,
        ticks = run.ticks,
        writes = run.writes,
        write_errors = run.write_errors,
        write_error = run.write_error,
        unreadable_ticks = run.unreadable,
        trial = run.runner:result(),
        program_ticks = run.program.total_ticks,
        settings = settings,
    }
end

return M
