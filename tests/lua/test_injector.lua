-- Unit tests for func/ComboExplorer/runtime/Injector.lua
--
-- This is the module core/Provenance.lua's INJECTION capability has existed for
-- since the first commit. `Provenance.can` had never been called from anywhere
-- in the shipping code; this is its first caller, so the gate itself is under
-- test here for the first time as well.
--
-- The adapter is a table, and start() reaches for the real one LAST - after
-- every refusal - so a register with nothing measured can be handed to it on a
-- machine with no Street Fighter.

local t = require("tests.lua.harness")
local Injector = require("func/ComboExplorer/runtime/Injector")
local Provenance = require("func/ComboExplorer/core/Provenance")
local InputMask = require("func/ComboExplorer/core/InputMask")

-- --- registers ----------------------------------------------------------------

local INJECTION_KEYS = { "modern_button_bits", "direction_bits", "rl_dir_polarity" }

local function fresh_register()
    return Provenance.new()
end

-- A register with the three injection entries settled. Their VALUES are the
-- provisional ones - this is a statement about the test, not an endorsement of
-- the guessed bit table.
local function measured_register()
    local reg = Provenance.new()
    for _, key in ipairs(INJECTION_KEYS) do
        reg.entries[key].status = Provenance.STATUS.VERIFIED
    end
    return reg
end

local ROUTE = {
    id = "r-inject-test",
    character = "zangief",
    control_scheme = "modern",
    steps = {
        { index = 1, action_id = 601, input_method = "manual",
          notation = "\229\188\177" },                  -- 弱
        { index = 2, action_id = 621, input_method = "manual",
          notation = "2 + \228\184\173" },              -- 2 + 中
    },
}

local SINK = { path = "ComboExplorer_data/trials/test.jsonl",
               dirs = { "ComboExplorer_data", "ComboExplorer_data/trials" } }

-- --- the gate -------------------------------------------------------------------

t.group("the gate the whole project is built around")

do
    local ok, why = Injector.start({ provenance = fresh_register(),
                                     allow_injection = true, route = ROUTE,
                                     delay = 4, sink = SINK })
    t.is_nil(ok, "a register with nothing measured cannot start a trial")
    t.ok(tostring(why):find("injection is blocked") ~= nil,
         "and says injection is blocked: " .. tostring(why))

    -- The refusal names them. A gate that says only "blocked" sends the
    -- operator to the source; this one sends them to the sweep.
    for _, key in ipairs(INJECTION_KEYS) do
        t.ok(tostring(why):find(key, 1, true) ~= nil,
             ("naming %s as one of the things to measure"):format(key))
    end
end

do
    local ok, why = Injector.start({ allow_injection = true, route = ROUTE, sink = SINK })
    t.is_nil(ok, "no register at all is refused")
    t.ok(tostring(why):find("no provenance register") ~= nil, "plainly: " .. tostring(why))
end

do
    -- The operator's own switch, checked AFTER the register. The register is
    -- the real gate; this is the second one.
    local ok, why = Injector.start({ provenance = measured_register(),
                                     allow_injection = false, route = ROUTE,
                                     delay = 4, sink = SINK })
    t.is_nil(ok, "a measured register still will not run with the switch off")
    t.ok(tostring(why):find("switched off") ~= nil,
         "and says it is the switch, not the register: " .. tostring(why))
end

do
    -- The calibration sweep is allowed to write with an UNMEASURED map because
    -- it is testing it. This is not, and the difference is what the gate is for.
    local reg = measured_register()
    local profile = InputMask.profile_from_provenance(Provenance, reg)
    t.eq(profile.measured, true, "a settled register produces a measured profile")

    local bare = InputMask.profile_from_provenance(Provenance, fresh_register())
    t.eq(bare.measured, false, "and an untouched one does not")
end

-- --- the sink -------------------------------------------------------------------

t.group("a trial whose result is not written did not happen")

do
    local sink, why = Injector.open_sink(nil)
    t.is_nil(sink, "no sink is a refusal, not a default")
    t.ok(tostring(why):find("did not happen") ~= nil, "and says why: " .. tostring(why))

    local off = Injector.open_sink(false)
    t.eq(off, false, "and `false` is the way to say recording is off on purpose")
end

do
    -- The encoder is checked once, at the start, rather than per record. On a
    -- build whose REFramework has no json.dump_string this refuses before the
    -- first trial instead of discovering it an hour in with the results gone.
    -- On this machine there is no json at all, which is the same path.
    local sink, why = Injector.open_sink(SINK)
    t.is_nil(sink, "with no encoder available the sink refuses to open")
    t.ok(tostring(why):find("cannot encode") ~= nil,
         "naming the encoder rather than the file: " .. tostring(why))
end

do
    -- The second shape (#45): a collector the caller already owns, which is
    -- how Sweep and RouteRun hand over theirs instead of writing beside it.
    local ResultCollector = require("func/ComboExplorer/core/ResultCollector")
    local c = ResultCollector.new({ append = function() return true end,
                                    encode = function() return "{}" end })
    local sink, why = Injector.open_sink({ collector = c })
    t.ok(type(sink) == "table", "a collector opens as a sink: " .. tostring(why))
    t.ok(sink and sink.collector == c, "and it is that collector, not a copy")

    local both, bwhy = Injector.open_sink({ collector = c, path = "x.jsonl" })
    t.is_nil(both, "a file AND a collector is refused")
    t.ok(tostring(bwhy):find("one place") ~= nil,
         "because a trial is written in one place: " .. tostring(bwhy))

    local mute, mwhy = Injector.open_sink({ collector = {} })
    t.is_nil(mute, "a collector that cannot append is not a sink")
    t.ok(tostring(mwhy):find("cannot append") ~= nil, tostring(mwhy))

    local empty, ewhy = Injector.open_sink({})
    t.is_nil(empty, "a sink table that names neither is no sink")
    t.ok(tostring(ewhy):find("did not happen") ~= nil, tostring(ewhy))
end

-- --- the tick counts ------------------------------------------------------------

t.group("the budgets the runner will not default")

do
    local RunnerFsm = require("func/ComboExplorer/core/RunnerFsm")
    for _, req in ipairs(RunnerFsm.REQUIRED) do
        t.ok(Injector.DEFAULTS[req.key] ~= nil,
             ("the shipped defaults supply %s"):format(req.key))
        t.ok(Injector.PROVENANCE[req.key] ~= nil,
             ("and say where %s came from"):format(req.key))
        t.ok(tostring(Injector.PROVENANCE[req.key]):find("guessed") ~= nil,
             ("%s is marked a guess, because it is one"):format(req.key))
    end

    -- The budget has to cover the program plus the window, or every trial times
    -- out and a sweep of timeouts looks like a sweep of hardware trouble.
    t.ok(Injector.DEFAULTS.trial_timeout_ticks > Injector.DEFAULTS.observe_ticks,
         "the trial budget is larger than the observation window alone")
end

do
    local cfg = Injector.config({ observe_ticks = 7 })
    t.eq(cfg.observe_ticks, 7, "an override reaches the config")
    t.eq(cfg.grace_ticks, Injector.DEFAULTS.grace_ticks, "and leaves the rest alone")
    t.eq(Injector.DEFAULTS.observe_ticks, 120, "without changing the defaults")
end

-- --- the mirror, which had no owner ---------------------------------------------

t.group("a direction is mirrored against the side the character is on")

-- SequenceCompiler has no mirror logic and RunnerFsm hands out inject_mask raw,
-- so the program carries whatever bit InputMask gave to "6" - forward only when
-- the character faces right. The Injector applies the mirror at WRITE time,
-- against the rl_dir of the frame the mask is spent on. These pin the behaviour
-- it depends on.

do
    local profile = InputMask.profile_from_provenance(Provenance, measured_register())
    local L, R = profile.dir.LEFT, profile.dir.RIGHT
    t.ok(L ~= nil and R ~= nil, "the profile names both horizontal bits")

    local mirrored = InputMask.mirror(R, false, profile)
    local straight = InputMask.mirror(R, true, profile)
    t.ok(mirrored ~= nil and straight ~= nil, "the mirror answers for both sides")
    t.ok(mirrored ~= straight,
         "and the two sides differ - which is the whole reason this happens at write time")

    -- One side leaves it alone and the other swaps it. Which is which is the
    -- measured polarity's business, not this test's.
    local swapped = (mirrored == L) or (straight == L)
    t.ok(swapped, "the direction bit is swapped on exactly one of the two sides")
end

do
    -- A profile the mirror cannot read is refused rather than guessed at. The
    -- write path treats nil as "do not write", because a direction written
    -- against an unknown polarity comes out backwards half the time.
    local nope, why = InputMask.mirror(4, true, nil)
    t.is_nil(nope, "no profile, no mirror")
    t.ok(why ~= nil, "and a reason: " .. tostring(why))
end

-- --- lifecycle ------------------------------------------------------------------

t.group("one trial at a time, and nothing parked after it")

do
    t.eq(Injector.running(), false, "nothing is running to begin with")
    t.is_nil(Injector.progress(), "so there is no progress to report")
    t.is_nil(Injector.result(), "and no result")
    t.is_nil(Injector.tick(), "and a tick does nothing")

    local rec, why = Injector.record(nil)
    t.is_nil(rec, "and there is nothing to record")
    t.ok(tostring(why):find("no trial") ~= nil, "which it says: " .. tostring(why))
end

do
    -- install() needs the suite's shared callback array. Without it the answer
    -- is a refusal that names what is missing, not a silent no-op: a sweep that
    -- runs while writing nothing would record every pair as not linking.
    local saved = _G._shared_input_post
    _G._shared_input_post = nil
    local ok, why = Injector.install(function() return true end)
    t.eq(ok, false, "with no shared input array, install fails")
    t.ok(tostring(why):find("_shared_input_post") ~= nil,
         "naming what is missing: " .. tostring(why))
    t.eq(Injector.install_error(), why, "and the reason is readable afterwards")
    _G._shared_input_post = saved
end

-- --- recording a finished trial -------------------------------------------------

t.group("record() hands the trial to the collector, and the collector writes it")

-- The bug this is written against: `ResultCollector.trial(collector, spec)`.
-- M.trial takes ONE argument and only BUILDS a record, so the collector was
-- being validated as if it were the spec and nothing was ever appended.
--
-- It survived because the only caller was Sweep, which passed nil to get the
-- spec back and did its own write. Anything recording through this path would
-- have written nothing, silently. Since #45 a trial with a sink is written by
-- tick() instead, and record(collector) is only for a run with recording off.

local StageControlFsm = require("func/ComboExplorer/core/StageControlFsm")

-- The snapshot shape both machines read, plus the two fields tick_snapshot adds.
local function snap(over)
    local s = {
        refreshing = false,
        attacker_pos = -150, victim_pos = 150,
        attacker_act_st = 0, victim_act_st = 0,
        combo_count = 0, guard_count = 0,
        attacker_hp = 10000, victim_hp = 10000,
        attacker_action_id = 1, attacker_hitstop = 0,
        can_inject = true,
    }
    for k, v in pairs(over or {}) do s[k] = v end
    return s
end

local function adapter()
    local log = { ticks = 0 }
    return {
        tick_snapshot = function()
            log.ticks = log.ticks + 1
            -- One tick of REQUEST, three with the flag high, then clear.
            if log.ticks >= 2 and log.ticks <= 4 then
                return snap({ refreshing = true })
            end
            return snap()
        end,
        request_refresh = function() return true end,
        set_position = function() return true end,
        pin_resources = function() return true, nil, {} end,
        write_setup = function() return true, nil, {} end,
        player = function() return nil end,
    }, log
end

do
    local reg = measured_register()

    -- sink = false: recording off, which is how a caller says so on purpose.
    -- It is also the only way to start a trial on this machine, since the real
    -- sink refuses when there is no encoder.
    local ok, why = Injector.start({
        provenance = reg, allow_injection = true, route = ROUTE, delay = 4,
        expected = { [1] = { 601 }, [2] = { 621 } },
        edge_id = "601:manual->621:manual", attempt = 1,
        frame = 4242,
        sink = false, adapter = adapter(),
    })
    t.ok(ok, "a trial starts with recording switched off: " .. tostring(why))

    local cmd
    for _ = 1, 3000 do
        cmd = Injector.tick()
        if cmd and cmd.outcome ~= nil then break end
    end
    t.ok(cmd ~= nil and cmd.outcome ~= nil,
         "and reaches an outcome: " .. tostring(cmd and cmd.outcome))

    -- With no collector it hands back the spec, which is what Sweep uses.
    local spec = Injector.record(nil)
    if spec then
        t.eq(type(spec), "table", "record(nil) returns the spec itself")
        t.eq(spec.edge_id, "601:manual->621:manual", "naming the pair it was about")

        -- THE ONE THAT WAS MISSING. `recorded_at` has been on the record shape
        -- since ResultCollector was written and nothing ever set it, so every
        -- tick number on a trial line was relative to that trial and reset on
        -- the next - a line could not be located in anything at all.
        t.ok(type(spec.recorded_at) == "string",
             "the trial says when it ran: " .. tostring(spec.recorded_at))
        t.ok(tostring(spec.recorded_at):find("T") ~= nil,
             "as an ISO timestamp, which is what a recording can be aligned to")
        t.eq(spec.started_at_frame, 4242,
             "and the engine frame travels beside it when the caller had one")
    else
        -- An outcome in M.NO_RECORD produces no record, and that IS its answer.
        t.ok(true, "this outcome produces no record, which is its answer")
    end

    -- With a collector it must APPEND. A collector whose append counts calls is
    -- the only way to tell writing from building.
    local appended = {}
    local ResultCollector = require("func/ComboExplorer/core/ResultCollector")
    local c = ResultCollector.new({
        append = function(line) appended[#appended + 1] = line return true end,
        encode = function(rec) return "{" .. tostring(rec.edge_id) .. "}" end,
        identity = { calibration_id = "cal-test", game_patch = "p" },
    })

    if spec then
        local rec, problems = Injector.record(c)
        local why_not = problems and problems[1] and tostring(problems[1].problem) or ""
        t.ok(rec ~= nil, "record(collector) produces a record: " .. why_not)
        t.eq(#appended, 1, "AND the line reached the collector's append")
    end

    -- Switched off on purpose, and the run says so rather than leaving the
    -- question of whether it was recorded unanswered.
    t.eq(Injector.result().recorded, Injector.RECORDED.OFF,
         "with recording off, the result says it was not recorded on purpose")

    Injector.stop()
end

-- --- the sink is written ----------------------------------------------------------

t.group("a judged trial is written to its sink, once (#45)")

-- The issue, measured on the machine: RUN ONE TRIAL passed a sink, the trial
-- reached `judged` with verdict a_failed, and trials.jsonl was never created.
-- start() had refused to run without a sink - "a trial whose result is not
-- written is a trial that did not happen" - and then nothing wrote to it.

local ResultCollector = require("func/ComboExplorer/core/ResultCollector")
local JsonIO = require("func/ComboExplorer/runtime/JsonIO")

local function counting_collector(append)
    local lines = {}
    local c = ResultCollector.new({
        append = append or function(line) lines[#lines + 1] = line return true end,
        encode = function(rec) return rec.schema .. " " .. tostring(rec.id) end,
        identity = { calibration_id = "cal-test", game_patch = "p" },
    })
    return c, lines
end

local function until_outcome()
    local cmd
    for _ = 1, 3000 do
        cmd = Injector.tick()
        if cmd and cmd.outcome ~= nil then break end
    end
    return cmd
end

local function trial_opts(over)
    local opts = {
        provenance = measured_register(), allow_injection = true, route = ROUTE,
        delay = 4, expected = { [1] = { 601 }, [2] = { 621 } },
        edge_id = "601:manual->621:manual", attempt = 1, adapter = adapter(),
    }
    for k, v in pairs(over or {}) do opts[k] = v end
    return opts
end

do
    Injector.stop()
    local c, lines = counting_collector()
    local ok, why = Injector.start(trial_opts({ sink = { collector = c } }))
    t.ok(ok, "a trial starts with a collector as its sink: " .. tostring(why))

    local cmd = until_outcome()
    -- The fake stage never lets A come out, which is exactly the trial the
    -- issue was filed from.
    t.eq(cmd and cmd.outcome, "judged", "the trial is judged")
    t.eq(#lines, 1, "and ONE line was written, on the tick the verdict arrived")
    t.ok(tostring(lines[1]):find("ce.trial.v1", 1, true) == 1,
         "as a ce.trial.v1 record, the collector's own shape: " .. tostring(lines[1]))

    local r = Injector.result()
    t.eq(r.recorded, Injector.RECORDED.WRITTEN, "the result says it was written")
    t.ok(type(r.record_id) == "string", "naming the record: " .. tostring(r.record_id))
    t.is_nil(r.record_error, "with no error")
    t.eq(Injector.progress().recorded, Injector.RECORDED.WRITTEN,
         "and progress, which the panel draws, says the same")

    -- More ticks after the outcome, and a caller that also asks to record:
    -- neither may produce a second line.
    for _ = 1, 5 do Injector.tick() end
    t.eq(#lines, 1, "further ticks do not write it again")
    local again, problems = Injector.record(c)
    t.is_nil(again, "record(collector) on a run with a sink is refused")
    t.ok(tostring(problems and problems[1] and problems[1].problem):find("twice") ~= nil,
         "because it would record one trial twice")
    t.eq(#lines, 1, "so the file still holds one line")
    t.eq(c.counts.written, 1, "and the collector counted one write")
    Injector.stop()
end

do
    -- The panel's shape: a path. A collector is built over it, so the line is
    -- the same record a sweep writes. JsonIO is stood in for, because this
    -- machine has no json.dump_string - which the refusal test above relies on.
    Injector.stop()
    local saved_encode, saved_append = JsonIO.encode_line, JsonIO.append
    local appended = {}
    JsonIO.encode_line = function(rec)
        local p = type(rec.provenance) == "table" and rec.provenance or {}
        return ("%s %s cal=%s"):format(tostring(rec.schema), tostring(rec.verdict),
                                       tostring(p.calibration_id))
    end
    JsonIO.append = function(path, line, dirs)
        appended[#appended + 1] = { path = path, line = line, dirs = dirs }
        return true
    end

    local sink = {
        path = "ComboExplorer_data/trials/trials.jsonl",
        dirs = { "ComboExplorer_data", "ComboExplorer_data/trials" },
        identity = { calibration_id = "cal-panel", game_patch = "p" },
    }
    local ok, why = Injector.start(trial_opts({ sink = sink }))
    t.ok(ok, "a trial starts with a file sink: " .. tostring(why))
    until_outcome()
    for _ = 1, 3 do Injector.tick() end
    local r = Injector.result()
    Injector.stop()
    JsonIO.encode_line, JsonIO.append = saved_encode, saved_append

    t.eq(#appended, 1, "the judged trial reached the file, once")
    t.eq(appended[1] and appended[1].path, sink.path, "at the path the panel gave")
    t.ok(appended[1] and appended[1].dirs == sink.dirs, "creating the directories it named")
    t.ok(tostring(appended[1] and appended[1].line):find("^ce.trial.v1 a_failed") ~= nil,
         "as a trial record carrying the verdict: " .. tostring(appended[1] and appended[1].line))
    t.ok(tostring(appended[1] and appended[1].line):find("cal=cal-panel", 1, true) ~= nil,
         "stamped with the identity the sink was given")
    t.eq(r.sink_path, sink.path, "and the result says where it went")
end

do
    -- A write that fails is on the run, not swallowed. "The move did not come
    -- out" and "the row did not reach the file" are different problems, so it
    -- is not folded into write_error either.
    Injector.stop()
    local c, _ = counting_collector(function() return false, "the disk is full" end)
    t.ok(Injector.start(trial_opts({ sink = { collector = c } })), "starts")
    local cmd = until_outcome()
    t.eq(cmd and cmd.outcome, "judged", "the trial is judged")

    local r = Injector.result()
    t.eq(r.recorded, Injector.RECORDED.FAILED, "the result says the write failed")
    t.ok(tostring(r.record_error):find("the disk is full", 1, true) ~= nil,
         "with the writer's own reason: " .. tostring(r.record_error))
    t.is_nil(r.write_error, "and not as a pad write error")
    t.ok(tostring(Injector.progress().record_error):find("disk is full") ~= nil,
         "progress carries it too, so the panel can show it while the run is up")
    t.eq(c.counts.write_failed, 1, "the collector counted the failure")
    Injector.stop()
end

do
    -- A writer that throws rather than returning false is the same fact to
    -- the operator - the row is not on disk - and is surfaced the same way.
    Injector.stop()
    local c = counting_collector(function() error("the writer threw") end)
    t.ok(Injector.start(trial_opts({ sink = { collector = c } })), "starts")
    until_outcome()
    local r = Injector.result()
    t.eq(r.recorded, Injector.RECORDED.FAILED, "a writer that throws is a failed write")
    t.ok(tostring(r.record_error):find("the writer threw", 1, true) ~= nil,
         "and says so: " .. tostring(r.record_error))
    Injector.stop()
end

-- --- the drivers, with the real Injector ------------------------------------------

t.group("a sweep's and a route run's rows are written once, by the real Injector")

-- The fakes in test_sweep and test_routerun keep the Injector's contract, but
-- a fake that keeps a contract cannot show the contract is what the real module
-- does. These run the two drivers against THIS Injector, with only the adapter
-- stood in, and count lines.

local Sweep = require("func/ComboExplorer/runtime/Sweep")
local RouteRun = require("func/ComboExplorer/runtime/RouteRun")

-- The real module, with the one thing a desk cannot provide slipped into every
-- start: neither driver passes an adapter, because on the machine there is
-- only one.
local function real_injector()
    return setmetatable({
        start = function(opts)
            opts.adapter = adapter()
            return Injector.start(opts)
        end,
    }, { __index = Injector })
end

do
    Injector.stop()
    Sweep.stop()
    local c, lines = counting_collector()
    local wl = {
        schema = "ce.worklist.v1", character = "zangief", control_scheme = "modern",
        pairs = {
            { a_id = 601, a_method = "manual", a_notation = ROUTE.steps[1].notation,
              b_id = 621, b_method = "manual", b_notation = ROUTE.steps[2].notation },
            { a_id = 621, a_method = "manual", a_notation = ROUTE.steps[2].notation,
              b_id = 601, b_method = "manual", b_notation = ROUTE.steps[1].notation },
        },
    }
    local ok, why = Sweep.start({ worklist = wl, collector = c, injector = real_injector(),
                                  provenance = measured_register(), delay = 4,
                                  allow_injection = true })
    t.ok(ok, "a sweep starts on the real Injector: " .. tostring(why))
    for _ = 1, 10000 do
        local p = Sweep.progress()
        if not p or p.done then break end
        Sweep.tick()
    end
    local r = Sweep.result()
    t.eq(r.done, true, "the sweep finishes: " .. tostring(r.stopped_because))
    t.eq(r.finished, 2, "having run both pairs")
    t.eq(#lines, 2, "and the file holds two lines - one per trial, not two per trial")
    t.eq(c.counts.written, 2, "the collector counted two writes")
    t.eq(r.problems, 0, "with nothing reported as failing to record")
    Sweep.stop()
    Injector.stop()
end

do
    Injector.stop()
    RouteRun.stop()
    local c, lines = counting_collector()
    local ok, why = RouteRun.start({ route = ROUTE, collector = c, delays = { 4, 6, 8 },
                                     injector = real_injector(),
                                     provenance = measured_register(),
                                     allow_injection = true })
    t.ok(ok, "a route run starts on the real Injector: " .. tostring(why))
    for _ = 1, 20000 do
        local p = RouteRun.progress()
        if not p or p.done then break end
        RouteRun.tick()
    end
    local p = RouteRun.progress()
    t.eq(p.done, true, "the route run finishes: " .. tostring(p.stopped_because))
    t.eq(p.finished, 3, "having tried all three gaps")
    t.eq(#lines, 3, "and the file holds three lines, not six")
    t.eq(p.problems, 0, "with nothing reported as failing to record")
    RouteRun.stop()
    Injector.stop()
end

-- --- the conditions the trial ran under ---------------------------------------------

t.group("every trial says what conditions it ran under")

-- `conditions` had been a field on the record since ResultCollector was written
-- and nothing had ever set one. A sweep run in that state produces rows that
-- cannot say whether the fighters were controlled or what the gauges held, and
-- none of it is recoverable afterwards.

local TestContext = require("func/ComboExplorer/core/TestContext")
local StageControl = require("func/ComboExplorer/runtime/StageControl")

local function run_one(over)
    local opts = {
        provenance = measured_register(), allow_injection = true, route = ROUTE,
        delay = 4, expected = { [1] = { 601 }, [2] = { 621 } },
        edge_id = "601:manual->621:manual", attempt = 1,
        sink = false, adapter = adapter(),
    }
    for k, v in pairs(over or {}) do opts[k] = v end
    local ok, why = Injector.start(opts)
    if not ok then return nil, why end
    local cmd
    for _ = 1, 3000 do
        cmd = Injector.tick()
        if cmd and cmd.outcome ~= nil then break end
    end
    local spec = Injector.record(nil)
    Injector.stop()
    return spec, cmd
end

do
    local spec = run_one()
    t.ok(spec ~= nil, "a trial produces a spec")
    t.ok(type(spec.conditions) == "table",
         "and it carries the conditions it ran under, rather than a nil")
    t.eq(spec.conditions.schema, TestContext.SCHEMA, "as a ce.conditions.v1 block")

    -- What StageControl actually ships. The honest record of a trial run today
    -- is "nothing was controlled", and writing anything else would describe an
    -- experiment nobody performed.
    t.eq(spec.conditions.positions.controlled, false,
         "which today says the positions were NOT controlled")
    t.eq(spec.conditions.resources.pinned, false, "and the gauges were not pinned")
    t.eq(spec.conditions.counter_state, TestContext.COUNTER.UNKNOWN,
         "and the counter state is unknown, because nothing observed it")

    t.ok(type(spec.conditions.canonical) == "string",
         "with the canonical string a later fold groups on: "
         .. tostring(spec.conditions.canonical))
end

-- A stage that pins a gauge only reaches READY once the snapshot reads that
-- gauge back, so the fake has to answer with it. That is StageControlFsm being
-- right - a pin it cannot verify is not a pin - rather than something to work
-- around.
local function adapter_reading(fields)
    local a = adapter()
    local underlying = a.tick_snapshot
    a.tick_snapshot = function(...)
        local s = underlying(...)
        if type(s) == "table" then
            for k, v in pairs(fields) do s[k] = v end
        end
        return s
    end
    return a
end

do
    -- Derived from the config that was APPLIED. Overriding the stage has to
    -- move the record, or the record is describing some other trial.
    local spec, why = run_one({ stage_cfg = { pin = { attacker_super = 3 } },
                                adapter = adapter_reading({ attacker_super = 3 }) })
    t.ok(spec ~= nil, "a trial with the gauges pinned runs: " .. tostring(why))
    t.eq(spec.conditions.resources.pinned, true, "and the record says they were pinned")
    t.eq(spec.conditions.resources.attacker_super, 3, "at the value that was pinned")

    local plain = run_one()
    t.ok(spec.conditions.canonical ~= plain.conditions.canonical,
         "so the two trials are not folded into one cohort")
end

do
    -- The derived block has to agree with what TestContext would say about the
    -- same config. If these ever diverge, one of the two is describing a setup
    -- that did not run.
    local spec = run_one()
    local direct = TestContext.of({ stage = StageControl.config(nil) })
    t.eq(spec.conditions.canonical, direct.canonical,
         "and it is the same block TestContext builds from the resolved config")

    -- The panel scopes its resume by conditions_for(), and a resume scoped by
    -- a block that differs from the one on the rows recognises nothing.
    local asked = Injector.conditions_for(nil)
    t.ok(asked ~= nil, "conditions_for answers without a game")
    t.eq(asked.canonical, spec.conditions.canonical,
         "and answers with exactly what a trial would record")

    local pinned = Injector.conditions_for({ pin = { attacker_super = 3 } })
    t.ok(pinned.canonical ~= asked.canonical,
         "while a different stage override gives a different answer")
end

do
    local spec = run_one({ opponent = { character = "Ryu" },
                           counter_state = TestContext.COUNTER.COUNTER })
    t.eq(spec.conditions.opponent.character, "Ryu",
         "what the caller KNOWS is folded in - the opponent")
    t.eq(spec.conditions.counter_state, TestContext.COUNTER.COUNTER,
         "and the counter state, when somebody actually observed it")
end

do
    -- Refused rather than ignored. A caller passing a block believes it is
    -- describing this trial; replacing it silently leaves that belief wrong.
    local ok, why = Injector.start({
        provenance = measured_register(), allow_injection = true, route = ROUTE,
        delay = 4, expected = { [1] = { 601 }, [2] = { 621 } },
        edge_id = "601:manual->621:manual", attempt = 1,
        sink = false, adapter = adapter(),
        conditions = { schema = "ce.conditions.v1", positions = { controlled = true } },
    })
    t.is_nil(ok, "a caller cannot supply the conditions")
    t.ok(tostring(why):find("derived from the stage configuration") ~= nil,
         "because this module is the only thing that knows what was applied: "
         .. tostring(why))
end

return t.finish()
