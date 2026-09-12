-- Unit tests for func/ComboExplorer/runtime/RouteRun.lua
--
-- The question this module exists to answer is #48's: does a route a human
-- knows connects come back as a link? Everything here is about not getting a
-- wrong answer to that - not skipping combinations, not stopping early, and
-- saying "no gap linked" plainly when that is what happened, because THAT is
-- the answer that invalidates every negative in #12's file.

local t = require("tests.lua.harness")
local RR = require("func/ComboExplorer/runtime/RouteRun")
local Route = require("func/ComboExplorer/core/Route")

-- --- a fake injector ----------------------------------------------------------

-- verdicts : delay-key -> verdict, or a function(key) -> verdict
local function injector(verdicts)
    local self = { started = {}, live = false, last = nil, stops = 0 }
    self.start = function(opts)
        if self.refuse then return nil, "the fake refused" end
        self.started[#self.started + 1] = opts
        self.last = opts
        self.live = true
        return true
    end
    self.running = function() return self.live end
    self.stop = function() self.live = false; self.stops = self.stops + 1 end
    self.result = function()
        local key = RR.key_for(self.last.delays)
        local v = verdicts
        if type(v) == "function" then v = v(key) else v = v[key] end
        v = v or "whiff"
        return { trial = { verdict = v, retryable = (v == "reset_failed") } }
    end
    -- The fake used to have a finish() the driver called by hand, and the
    -- driver stopped it. That hid the defect this file exists to catch:
    -- production has no such hand, and Injector.running() stays true until
    -- somebody calls stop(), so the run sat on combination 1 of 144 forever.
    --
    -- So the fake behaves the way the real one does: a tick returns a command,
    -- and the OUTCOME on it is the only signal that the trial is over.
    self.ticks = 0
    self.tick = function()
        self.ticks = self.ticks + 1
        -- Two ticks of work, then done. More than one so a driver that acts on
        -- the first tick regardless would be visible.
        if self.ticks % 2 == 0 then return { outcome = "judged" } end
        return { outcome = nil }
    end
    -- The spec a finished trial offers for recording. RouteRun must write
    -- through the COLLECTOR: the Injector's sink is opened and never used
    -- (#45), so a run that trusted it would record nothing while reporting a
    -- path, and "every gap was tried and none linked" is worth nothing if the
    -- gaps are not on disk.
    self.record = function() return { spec_for = RR.key_for(self.last.delays) } end
    return self
end

local ROUTE = {
    id = "ground-truth",
    steps = {
        { index = 1, action_id = 660, input_method = "simple", notation = "AUTO + 强" },
        { index = 2, action_id = 655, input_method = "manual", notation = "3 + 中" },
        { index = 3, action_id = 900, input_method = "simple", notation = "2 + SP" },
    },
}

-- A REAL collector with a no-op sink. A stand-in table would have hidden the
-- thing this most needs to be right: RouteRun writes through the collector,
-- not through the Injector's sink, which is opened and never used (#45).
local ResultCollector = require("func/ComboExplorer/core/ResultCollector")
local function collector(lines)
    local c = ResultCollector.new({
        append = function(line) if lines then lines[#lines + 1] = line end return true end,
        -- Enough to be a line; nothing here reads it back.
        encode = function(v) return "{}" end,
        identity = { calibration_id = "test", game_patch = "test" },
    })
    return c
end

-- Ticked the way the panel ticks it, and NOTHING else. Anything the driver
-- needs to do to end a trial has to happen inside RouteRun, because on the
-- machine there is nobody else to do it.
local function drive(_inj, want)
    -- Ticked until `want` trials have finished or the run ends. The bound is a
    -- backstop against the failure this file is here for: a driver that never
    -- ends a trial would otherwise loop here forever rather than failing.
    for _ = 1, want * 8 + 8 do
        local p = RR.progress()
        if not p or p.done or p.finished >= want then break end
        RR.tick()
    end
end

-- --- what it refuses ----------------------------------------------------------

t.group("what it will not start")

do
    RR.stop()
    local ok, why = RR.start({ collector = collector() })
    t.is_nil(ok, "no route, no run")
    t.ok(tostring(why):find("no route") ~= nil, "and it says so: " .. tostring(why))
end

do
    local ok, why = RR.start({ route = ROUTE })
    t.is_nil(ok, "no collector, no run")
    t.ok(tostring(why):find("cannot record") ~= nil,
         "for the reason Sweep gives: " .. tostring(why))
end

do
    local ok, why = RR.start({ route = ROUTE, collector = collector(), delays = {} })
    t.is_nil(ok, "an empty delay list is nothing to try")
    t.ok(tostring(why):find("empty") ~= nil, tostring(why))
end

-- --- the grid -----------------------------------------------------------------

t.group("two gaps are tried against each other, not walked in step")

do
    RR.stop()
    local inj = injector({})
    t.ok(RR.start({ route = ROUTE, collector = collector(), injector = inj,
                    delays = { 2, 4, 6 } }), "starts")
    local p = RR.progress()
    t.eq(p.total, 9, "three values over two gaps is nine combinations, not three")

    drive(inj, 12)
    t.eq(RR.progress().finished, 9, "and every one of them ran")

    local seen = {}
    for _, o in ipairs(inj.started) do seen[RR.key_for(o.delays)] = true end
    t.ok(seen["2/6"], "including the ones a zipped walk would never reach")
    t.ok(seen["6/2"], "in both orders - the gaps are different questions")
    RR.stop()
end

do
    -- A two-step route has ONE gap, so the grid is the list.
    RR.stop()
    local two = { id = "r", steps = { ROUTE.steps[1], ROUTE.steps[2] } }
    local inj = injector({})
    RR.start({ route = two, collector = collector(), injector = inj, delays = { 2, 4 } })
    t.eq(RR.progress().total, 2, "one gap, two combinations")
    RR.stop()
end

-- --- what each trial is told ---------------------------------------------------

t.group("the trial is told what the route says, and nothing else")

do
    RR.stop()
    local inj = injector({})
    RR.start({ route = ROUTE, collector = collector(), injector = inj,
               delays = { 4 }, stage_cfg = { target_positions = { attacker = -45, victim = 45 } } })
    drive(inj, 2)

    local o = inj.started[1]
    t.eq(#o.route.steps, 3, "all three steps go to the injector")
    t.eq(#o.delays, 2, "with one delay per gap")
    -- Built from the route, not stated a second time: a second statement of
    -- the same intent is free to disagree with the first.
    t.eq(o.expected[1][1], 660, "the expected ids come from the route's own steps")
    t.eq(o.expected[2][1], 655, "in order")
    t.eq(o.expected[3][1], 900, "all of them")
    t.ok(o.stage_cfg ~= nil, "and the stage setup is passed through")
    t.ok(tostring(o.edge_id):find("4/4") ~= nil,
         "the edge id carries the gaps, so two rows are distinguishable: " .. tostring(o.edge_id))
    RR.stop()
end

-- --- retries -------------------------------------------------------------------

t.group("a trial that measured nothing has not tried its combination")

do
    RR.stop()
    local tries = 0
    local inj = injector(function(key)
        if key == "4/4" then
            tries = tries + 1
            if tries < 3 then return "reset_failed" end
            return "link"
        end
        return "whiff"
    end)
    RR.start({ route = ROUTE, collector = collector(), injector = inj, delays = { 4 } })
    drive(inj, 6)

    t.eq(tries, 3, "it came back until it measured something")
    t.eq(RR.progress().links, 1, "and the answer is the one that measured")
    t.eq(RR.progress().done, true, "then the run finished")
    RR.stop()
end

do
    -- A combination that fails every time must not loop forever. That failure
    -- looks exactly like progress from outside.
    RR.stop()
    local inj = injector({ ["4/4"] = "reset_failed" })
    RR.start({ route = ROUTE, collector = collector(), injector = inj,
               delays = { 4 }, max_attempts = 2 })
    drive(inj, 10)
    t.eq(#inj.started, 2, "it stops at the cap")
    t.eq(RR.progress().done, true, "and the run ends rather than spinning")
    RR.stop()
end


-- --- nobody else is going to end the trial --------------------------------------

t.group("the driver ends its own trials")

-- The defect this is written from, measured on build 24176760: tick() returned
-- inj.tick() and looked at nothing. Injector.running() stays true until
-- somebody calls stop(), so the run sat on combination 1 of 144 for minutes
-- while reporting "running" - indistinguishable from a slow trial. The test
-- suite could not see it because the fake had a finish() the test driver called
-- by hand, and on the machine there is no such hand.

do
    RR.stop()
    local inj = injector({})
    RR.start({ route = ROUTE, collector = collector(), injector = inj, delays = { 4 } })

    -- Ticked only. Nothing outside RouteRun touches the injector.
    for _ = 1, 20 do RR.tick() end

    t.ok(inj.stops >= 1, "the injector was stopped by the driver, not by the test")
    t.eq(RR.progress().finished, 1, "and the combination counts as tried")
    t.eq(RR.progress().done, true, "so a one-combination run reaches the end")
    RR.stop()
end

do
    -- And it does not end one early. The outcome is the signal, not the tick
    -- count.
    RR.stop()
    local inj = injector({})
    RR.start({ route = ROUTE, collector = collector(), injector = inj, delays = { 4 } })
    RR.tick()   -- starts it
    RR.tick()   -- one tick of work, outcome still nil
    t.eq(RR.progress().finished, 0, "a trial with no outcome yet is not finished")
    t.eq(inj.stops, 0, "and the injector is still holding the frame")
    RR.stop()
end

-- --- the answer ----------------------------------------------------------------

t.group("the sentence #48 is asking for")

do
    RR.stop()
    local inj = injector({ ["6/4"] = "link" })
    RR.start({ route = ROUTE, collector = collector(), injector = inj, delays = { 4, 6 } })
    drive(inj, 8)
    local v = RR.verdict()
    t.ok(v:find("linked at 1") ~= nil, "it says how many gaps linked: " .. v)
    t.ok(v:find("6/4") ~= nil, "and which ones - a one-frame window is a finding")
    RR.stop()
end

do
    -- The answer that matters most, and it must not read as "this combo is
    -- hard". It invalidates every negative in the sweep.
    RR.stop()
    local inj = injector({})
    RR.start({ route = ROUTE, collector = collector(), injector = inj, delays = { 4, 6 } })
    drive(inj, 8)
    local v = RR.verdict()
    t.ok(v:find("NO gap linked") ~= nil, "it says so plainly: " .. v)
    t.ok(v:find("unexplained") ~= nil,
         "and what that means for everything else measured")
    RR.stop()
end

do
    RR.stop()
    local inj = injector({})
    RR.start({ route = ROUTE, collector = collector(), injector = inj, delays = { 2, 4, 6 } })
    drive(inj, 3)
    local v = RR.verdict()
    t.ok(v:find("yet") ~= nil, "mid-run it does not claim an answer: " .. v)
    RR.stop()
end

-- --- every combination is recorded ----------------------------------------------

t.group("the failures are the record too")

do
    -- A file with only the gaps that worked cannot tell "one gap in a hundred"
    -- from "every gap tried", and those are different combos.
    RR.stop()
    local inj = injector({ ["4/4"] = "link" })
    RR.start({ route = ROUTE, collector = collector(), injector = inj, delays = { 2, 4 } })
    drive(inj, 8)
    local p = RR.progress()
    t.eq(p.finished, 4, "every combination ran")
    t.eq(p.by_verdict.link, 1, "one linked")
    t.eq(p.by_verdict.whiff, 3, "and the other three are counted, not dropped")
    RR.stop()
end


-- --- the rows reach the collector ----------------------------------------------

t.group("every combination is written, not just counted")

do
    RR.stop()
    local written = {}
    local fake_collector = { written = written }
    -- ResultCollector.write is what RouteRun calls; stand in for it by
    -- swapping the module's function, the same seam test_config uses.
    local RC = require("func/ComboExplorer/core/ResultCollector")
    local saved = RC.write
    RC.write = function(c, spec)
        written[#written + 1] = spec
        return { ok = true }
    end

    local inj = injector({ ["4/4"] = "link" })
    RR.start({ route = ROUTE, collector = fake_collector, injector = inj, delays = { 2, 4 } })
    drive(inj, 8)
    RC.write = saved

    t.eq(#written, 4, "all four combinations were offered to the collector")
    t.eq(written[1].spec_for, "2/2", "starting with the first")
    RR.stop()
end

do
    -- A collector that refuses is a problem, not a silent loss. The whole
    -- answer rests on the rows existing.
    RR.stop()
    local RC = require("func/ComboExplorer/core/ResultCollector")
    local saved = RC.write
    RC.write = function() return nil, { { problem = "the disk said no" } } end

    local inj = injector({})
    RR.start({ route = ROUTE, collector = {}, injector = inj, delays = { 4 } })
    drive(inj, 3)
    RC.write = saved

    local p = RR.progress()
    t.ok(p.problems >= 1, "the refusal is recorded as a problem")
    t.ok(tostring(p.problem_detail[1].reason):find("would not record") ~= nil,
         "naming what happened: " .. tostring(p.problem_detail[1].reason))
    RR.stop()
end

-- --- a refusal to start is not a trial ------------------------------------------

t.group("an injector that will not start is reported, not counted as a result")

do
    RR.stop()
    local inj = injector({})
    inj.refuse = true
    RR.start({ route = ROUTE, collector = collector(), injector = inj, delays = { 4 } })
    RR.tick()
    local p = RR.progress()
    t.eq(p.started, 0, "nothing started")
    t.eq(p.problems, 1, "and the refusal is a problem")
    t.ok(tostring(p.problem_detail[1].reason):find("refused") ~= nil,
         "carrying the reason: " .. tostring(p.problem_detail[1].reason))
    RR.stop()
end

return t.finish()
