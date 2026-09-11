-- =========================================================
-- ComboExplorer/core/SequenceCompiler.lua - turns a route into the tick program
-- the injector writes. Pure: a route in, a mask per tick out.
-- =========================================================
--
-- THE DELAY IS NOT AN INPUT TO THIS MODULE'S KNOWLEDGE
--
-- A route arrives with `delay_ticks = nil` on every step, and this module will
-- not fill it in. How long to wait between two moves is the one thing the sweep
-- exists to measure, so the caller supplies a delay and the compiler builds the
-- program for exactly that delay. Compiling with no delay is an error rather
-- than a default: a default would be a guess, and a guess that produces a
-- working-looking program is the worst kind.
--
-- WHAT A DELAY MEANS HERE
--
-- Ticks of neutral between the END of one move's input and the START of the
-- next one's. Not frames of advantage, not recovery, not anything the frame
-- table talks about - just how long the pad is released. Whether one tick is
-- one engine frame is itself unverified (Provenance.tick_equals_frame), which
-- is why every count in the output is called a tick.
--
-- REFUSING AN UNVERIFIED PROFILE
--
-- Delegated to InputMask.compile, and deliberately not worked around. A wrong
-- button bit does not raise anything: it presses a button that does not exist,
-- the move never comes out, and the trial is recorded as "these moves do not
-- link" - a confident negative that looks exactly like a real one.
--
-- THE TAIL IS NOT THE OBSERVATION WINDOW
--
-- `tail_ticks` appends neutral ticks to the PROGRAM. It is a preview aid - it
-- makes `describe` show the release, and it gives an offline reader something
-- after the last button - and it is not how long anybody watches.
--
-- The window belongs to RunnerFsm. After the program's last tick the runner
-- enters OBSERVING and keeps watching for `observe_ticks`, a value it refuses
-- to start without (RunnerFsm.REQUIRED) precisely because nobody has measured
-- how late a result can arrive: a hit that lands during a super freeze or a
-- slow knockdown shows up long after the pad is neutral.
--
-- These were being added together. The default tail was 30 ticks, the runner
-- observed for another `observe_ticks` on top, and the evidence row recorded
-- only the second number - so the window in the data was shorter than the
-- window that actually ran, and the one figure an analyst would use to say
-- "we watched long enough" was the wrong one. Worse, the 30 was picked by
-- nobody from nothing. It is the sort of unmeasured constant this project
-- keeps in Provenance, and it was not in Provenance.
--
-- So the default is 0 and RunnerFsm refuses a program that carries a tail.
-- A caller that wants trailing neutral for a preview asks for it by name, and
-- such a program is then, correctly, not something a trial will run.
--
-- FOLLOW-UPS
--
-- A target-combo derivation cannot be produced from neutral, which is why
-- InputMask.compile refuses one outright. In a route it is a different case: the
-- move before it is the context that makes it available, so a follow-up is
-- compiled normally when it is not the first step, and refused when it is.

local InputMask = require("func/ComboExplorer/core/InputMask")

local M = { name = "ComboExplorer.SequenceCompiler" }

M.DEFAULTS = {
    lead_ticks = 10,     -- neutral before the first move, so the reset settles
    hold_ticks = 3,      -- how long each move's final direction + button is held
    -- Neutral appended after the last move. Zero by default: the observation
    -- window is RunnerFsm's (see the header). A preview asks for a tail by
    -- name, and gets a program a runner will refuse - which is the right way
    -- round, because a preview is not a trial.
    tail_ticks = 0,
    max_ticks = 600,     -- a program longer than this is a bug, not a combo
}

-- --- one step ----------------------------------------------------------------

-- Compiles a single route step to InputMask's { frames, mask } list, with no
-- lead and no tail: the route owns the gaps between moves.
local function compile_step(step, index, opts)
    local notation = step.notation or step.classic
    if type(notation) ~= "string" or notation == "" then
        return nil, ("step %d has no notation to compile"):format(index)
    end

    local parsed, perr = InputMask.parse(notation)
    if not parsed then
        return nil, ("step %d (%s): %s"):format(index, notation, tostring(perr))
    end

    if parsed.followup then
        if index == 1 then
            return nil, ("step %d (%s) is a target-combo derivation and cannot open a route"
                ):format(index, notation)
        end
        -- Inside a route the preceding move IS the context, so the derivation is
        -- producible. The flag is cleared for the compile and recorded on the
        -- program, because it changes what a failed trial means: the move not
        -- coming out may be the previous step not having connected.
        parsed = { air = parsed.air, any_button = parsed.any_button, assist = parsed.assist,
                   followup = false, dirs = parsed.dirs, buttons = parsed.buttons,
                   raw = parsed.raw }
    end

    local seq, cerr = InputMask.compile(parsed, {
        profile = opts.profile,
        allow_unverified = opts.allow_unverified,
        lead_ticks = 0,
        hold_ticks = opts.hold_ticks,
        tail_ticks = 0,
    })
    if not seq then
        return nil, ("step %d (%s): %s"):format(index, notation, tostring(cerr))
    end
    return seq, nil, parsed
end

-- --- the program -------------------------------------------------------------

local function seq_ticks(seq)
    local n = 0
    for _, s in ipairs(seq) do n = n + (s.frames or 0) end
    return n
end

-- route : a ce.route.v1
-- opts.profile          : an InputMask profile (refused unless verified)
-- opts.delays           : one delay per gap, so #steps - 1 of them
-- opts.delay            : a single delay used for every gap
-- opts.lead/hold/tail_ticks, opts.max_ticks : see M.DEFAULTS
-- opts.allow_unverified : read-only preview only. Never for a real trial.
--
-- Returns program, or nil, reason.
function M.compile(route, opts)
    opts = opts or {}
    if type(route) ~= "table" or type(route.steps) ~= "table" then
        return nil, "not a route"
    end
    local n = #route.steps
    if n < 2 then return nil, "a route needs at least two steps" end

    local cfg = {}
    for k, v in pairs(M.DEFAULTS) do cfg[k] = v end
    for k in pairs(M.DEFAULTS) do if opts[k] ~= nil then cfg[k] = opts[k] end end

    -- The delays. Absent is an error, not a default.
    local delays = {}
    if opts.delays ~= nil then
        if #opts.delays ~= n - 1 then
            return nil, ("a %d-step route needs %d delays, got %d")
                :format(n, n - 1, #opts.delays)
        end
        for i, d in ipairs(opts.delays) do delays[i] = d end
    elseif opts.delay ~= nil then
        for i = 1, n - 1 do delays[i] = opts.delay end
    else
        return nil, "no delay given - the delay between two moves is what the sweep "
            .. "measures, so it has to be supplied rather than assumed"
    end
    for i, d in ipairs(delays) do
        if type(d) ~= "number" or d < 0 or math.floor(d) ~= d then
            return nil, ("delay %d is not a non-negative whole number of ticks"):format(i)
        end
    end

    local seq = {}
    local steps = {}
    local boundaries = {}
    local tick = 0
    local context_dependent = false

    if cfg.lead_ticks > 0 then
        seq[#seq + 1] = { frames = cfg.lead_ticks, mask = 0 }
        tick = tick + cfg.lead_ticks
    end

    for i, step in ipairs(route.steps) do
        if i > 1 then
            local d = delays[i - 1]
            if d > 0 then
                seq[#seq + 1] = { frames = d, mask = 0 }
                tick = tick + d
            end
            boundaries[#boundaries + 1] = {
                after_step = i - 1, before_step = i,
                delay_ticks = d, input_starts_at_tick = tick,
            }
        end

        local part, err, parsed = compile_step(step, i, {
            profile = opts.profile,
            allow_unverified = opts.allow_unverified,
            hold_ticks = cfg.hold_ticks,
        })
        if not part then return nil, err end

        local dur = seq_ticks(part)
        steps[#steps + 1] = {
            index = i,
            action_id = step.action_id,
            input_method = step.input_method,
            notation = step.notation,
            classic = step.classic,
            -- Where in the program this move's input lives. The runner needs
            -- this to attribute a combo-count increase to the right move: the
            -- catalog's action ids are only confirmed by what comes out AFTER
            -- this tick.
            input_starts_at_tick = tick,
            input_ends_at_tick = tick + dur,
            input_ticks = dur,
            context_dependent = step.context_dependent or false,
        }
        if step.context_dependent then context_dependent = true end
        if parsed and parsed.assist then steps[#steps].assist = true end

        for _, s in ipairs(part) do seq[#seq + 1] = s end
        tick = tick + dur
    end

    -- Read into a local with a branch rather than inline. `opts.profile and
    -- opts.profile.measured or nil` turns an explicit `false` into nil, and nil
    -- means "nobody said" - the one reading that lets a program past every gate
    -- downstream.
    local profile_measured = nil
    if opts.profile ~= nil then profile_measured = opts.profile.measured end

    local observe_from = tick
    if cfg.tail_ticks > 0 then
        seq[#seq + 1] = { frames = cfg.tail_ticks, mask = 0 }
        tick = tick + cfg.tail_ticks
    end

    if tick > cfg.max_ticks then
        return nil, ("program is %d ticks, over the %d-tick limit"):format(tick, cfg.max_ticks)
    end

    return {
        route_id = route.id,
        character = route.character,
        control_scheme = route.control_scheme,
        seq = seq,
        raw_inputs = InputMask.expand(seq),
        total_ticks = tick,
        delays = delays,
        steps = steps,
        boundaries = boundaries,
        observe_from_tick = observe_from,
        -- Carried so the runner can tell a trial program from a preview one.
        -- Without it the runner cannot see a second window being counted.
        tail_ticks = cfg.tail_ticks,
        context_dependent = context_dependent,
        -- Carried so a program can never be replayed under a different profile
        -- than the one it was built for without that being visible.
        profile_status = opts.profile and opts.profile.status or nil,
        -- The question the runner and the collector both want answered. Kept
        -- beside the status rather than replacing it, so a report can still say
        -- which kind of measurement it was.
        profile_measured = profile_measured,
        profile_buttons_underivable = opts.profile and opts.profile.buttons_underivable or nil,
        profile_source = opts.profile and opts.profile.source or nil,
        tick_basis = "explorer_tick",
    }
end

-- Was the button map behind this program measured at all?
--
-- One owner for the question, because two gates ask it - the runner before it
-- starts a trial, the collector before it records one - and they were asking it
-- differently. Both used to test `profile_status ~= "verified"`, which refuses a
-- measurement that corrected a guess: exactly the case a successful calibration
-- sweep produces.
--
-- Returns nil when the program says nothing. nil is not false: a program with no
-- profile information has not claimed to be unmeasured, and refusing it would be
-- treating silence as bad news. A program that carries only the older
-- profile_status is read through it, since "unverified" is that field saying the
-- same thing.
function M.program_is_measured(program)
    if type(program) ~= "table" then return nil end
    if program.profile_measured ~= nil then return program.profile_measured end
    if program.profile_status ~= nil then
        return program.profile_status ~= "unverified"
    end
    return nil
end

-- --- sweeping ----------------------------------------------------------------

-- One gap varied across a range, the others held. Sweeping every gap at once is
-- a product, and a three-step route over thirteen delays is 169 trials for one
-- route - so the caller says which gap it is asking about.
--
-- opts.gap        : which gap to vary (1 = between steps 1 and 2). Default 1.
-- opts.range      : { from, to, step }. Default { from = 0, to = 12, step = 1 }.
-- opts.fixed      : delay for the other gaps. Required when the route has more
--                   than two steps, for the same reason a delay is required at
--                   all.
--
-- Returns programs, problems. A delay that will not compile is reported rather
-- than dropped: "this delay produces no program" and "this delay was never
-- tried" are different, and only the first is an answer.
function M.sweep(route, opts)
    opts = opts or {}
    if type(route) ~= "table" or type(route.steps) ~= "table" then
        return nil, "not a route"
    end
    local gaps = #route.steps - 1
    if gaps < 1 then return nil, "a route needs at least two steps" end

    local gap = opts.gap or 1
    if gap < 1 or gap > gaps then
        return nil, ("gap %d is outside the %d gaps this route has"):format(gap, gaps)
    end

    local range = opts.range or { from = 0, to = 12, step = 1 }
    local from = range.from or 0
    local to = range.to or 12
    local by = range.step or 1
    if by < 1 then return nil, "a sweep step of less than one tick would not terminate" end

    if gaps > 1 and opts.fixed == nil then
        return nil, "a route with more than one gap needs opts.fixed for the gaps "
            .. "that are not being swept"
    end

    local programs, problems = {}, {}
    for d = from, to, by do
        local delays = {}
        for i = 1, gaps do delays[i] = (i == gap) and d or opts.fixed end
        local prog, err = M.compile(route, {
            profile = opts.profile,
            allow_unverified = opts.allow_unverified,
            delays = delays,
            lead_ticks = opts.lead_ticks, hold_ticks = opts.hold_ticks,
            tail_ticks = opts.tail_ticks, max_ticks = opts.max_ticks,
        })
        if prog then
            prog.swept_gap = gap
            prog.swept_delay = d
            programs[#programs + 1] = prog
        else
            problems[#problems + 1] = { delay = d, reason = err }
        end
    end
    return programs, problems
end

-- --- inspection --------------------------------------------------------------

-- A one-line-per-tick view, for eyeballing a program before it is ever injected.
function M.describe(program, profile)
    if type(program) ~= "table" then return {} end
    local out = {}
    for i, mask in ipairs(program.raw_inputs) do
        out[i] = ("%4d  0x%04X  %s"):format(i, mask,
            profile and InputMask.describe(mask, profile) or "")
    end
    return out
end

return M
