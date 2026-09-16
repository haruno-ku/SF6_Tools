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
        self.record_error = nil
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
        return { record_error = self.record_error,
                 trial = { verdict = v, retryable = (v == "reset_failed") } }
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
        if self.ticks % 2 == 0 then
            -- The real Injector's contract (#45): the row is written through
            -- the sink the trial was started with, on the tick the outcome
            -- arrives, and result() says whether it landed. RouteRun writes
            -- nothing itself any more - its collector IS that sink - so the
            -- fake has to do the writing or every run would look empty.
            --
            -- ResultCollector.write is looked up here rather than captured,
            -- so the tests below that stand in for it still see every row.
            local sink = self.last.sink
            if sink and sink.collector then
                local RC = require("func/ComboExplorer/core/ResultCollector")
                local rec, problems = RC.write(sink.collector, self.record())
                if not rec then
                    self.record_error = tostring(problems and problems[1]
                                                 and problems[1].problem)
                end
            end
            return { outcome = "judged" }
        end
        return { outcome = nil }
    end
    -- The spec a finished trial offers for recording.
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

-- A REAL collector with a no-op append. A stand-in table would have hidden
-- the thing this most needs to be right: every trial's row goes through this
-- collector, handed to the Injector as its sink, and through nothing else
-- (#45).
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
    -- #14. This used to be edge_id = "ground-truth@4/4": a fake pair, which
    -- confirm.lua would have folded into the confirmed list as if it linked.
    t.eq(o.route_id, "ground-truth", "the trial is about the route, by its own id")
    t.is_nil(o.edge_id, "and it names no edge, because a route run is not a pair")
    t.eq_list(o.delays, { 4, 4 }, "the gaps travel as the delays, not inside an id")
    RR.stop()
end

t.group("a route row is written with the route as its subject (#14)")

do
    -- The injector's record is built from what RouteRun handed it, the way
    -- RunnerFsm.record_spec builds it from the spec, so the row that lands is
    -- the row the game would write.
    RR.stop()
    local lines = {}
    local json = dofile("tools/lua/json.lua")
    local c = ResultCollector.new({
        append = function(line) lines[#lines + 1] = line return true end,
        encode = json.encode,
        identity = { calibration_id = "test", game_patch = "test" },
    })
    local inj = injector({ ["4/6"] = "link" })
    inj.record = function()
        local o = inj.last
        return { edge_id = o.edge_id, route_id = o.route_id, delays = o.delays,
                 attempt = o.attempt, verdict = inj.result().trial.verdict,
                 evidence = { hits_added = 1 } }
    end
    RR.start({ route = ROUTE, collector = c, injector = inj, delays = { 4, 6 } })
    drive(inj, 8)

    t.eq(#lines, 4, "every combination reached the file")
    local rows, keys = {}, {}
    for i, l in ipairs(lines) do
        rows[i] = json.decode(l)
        keys[ResultCollector.key(rows[i])] = true
    end
    t.eq(rows[1].subject_kind, "route", "its subject is a route")
    t.eq(rows[1].subject_id, "ground-truth", "named by the route's own id")
    t.eq(rows[1].route_id, "ground-truth", "which route_id spells the same way")
    t.is_nil(rows[1].edge_id, "with no edge id for anything that folds pairs to pick up")
    t.ok(keys["route ground-truth @ 4,6 #1"],
         "the key carries the whole gap vector, so each combination is its own trial")
    local n = 0
    for _ in pairs(keys) do n = n + 1 end
    t.eq(n, 4, "four combinations, four distinct keys")
    RR.stop()
end


-- --- the whole notation group is what was asked for ---------------------------

t.group("a step expects every id its notation names")

-- Measured on build 24176760: the route named 900 for "2 + SP" and the game
-- produced 903, which is the SAME notation in the same catalog - one of the
-- thirteen ambiguous groups Probe D counts. Nineteen of thirty trials came back
-- "saw action id(s) 903 instead" on a combo that had in fact connected.

do
    RR.stop()
    -- A catalog where one notation names two ids, which is the shape that
    -- caused it.
    local cat = { groups = {
        g1 = { notation = "AUTO + 强", action_ids = { 660 } },
        g2 = { notation = "3 + 中", action_ids = { 655 } },
        g3 = { notation = "2 + SP", action_ids = { 900, 903 } },
    } }
    local inj = injector({})
    RR.start({ route = ROUTE, collector = collector(), injector = inj,
               catalog = cat, delays = { 4 } })
    drive(inj, 1)

    local exp = inj.started[1].expected
    t.eq(#exp[3], 2, "the step that named 900 expects both ids of its group")
    local ids = {}
    for _, id in ipairs(exp[3]) do ids[id] = true end
    t.ok(ids[900] and ids[903], "900 and 903 - the catalog says they are one notation")
    t.eq(#exp[1], 1, "a group with one id still expects one")
    RR.stop()
end

do
    -- No catalog: the file's id is all there is. That is the honest fallback,
    -- not a reason to refuse - a run can start before a battle resolves one.
    RR.stop()
    local inj = injector({})
    RR.start({ route = ROUTE, collector = collector(), injector = inj, delays = { 4 } })
    drive(inj, 1)
    t.eq(#inj.started[1].expected[3], 1, "one id, the one the file named")
    t.eq(inj.started[1].expected[3][1], 900, "unchanged")
    RR.stop()
end

do
    -- An id the catalog does not have keeps the file's own. Route.build already
    -- refuses that case with a catalog present; this is the belt.
    RR.stop()
    local cat = { groups = { g = { notation = "x", action_ids = { 1 } } } }
    local inj = injector({})
    RR.start({ route = ROUTE, collector = collector(), injector = inj,
               catalog = cat, delays = { 4 } })
    drive(inj, 1)
    t.eq(inj.started[1].expected[1][1], 660, "the step keeps what the file said")
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
    -- #45. The collector is the trial's sink, so there is one writer. RouteRun
    -- used to write each row itself while the panel handed the Injector the
    -- same file as a sink; the day that sink started writing, every gap would
    -- have been in the file twice.
    --
    -- Every write is counted, whoever makes it: the fake injector writes once
    -- per trial, so anything above four is RouteRun writing as well.
    RR.stop()
    local RC = require("func/ComboExplorer/core/ResultCollector")
    local saved = RC.write
    local writes = 0
    RC.write = function() writes = writes + 1 return { ok = true } end

    local c = collector()
    local inj = injector({})
    RR.start({ route = ROUTE, collector = c, injector = inj, delays = { 2, 4 } })
    drive(inj, 8)
    RC.write = saved

    t.eq(#inj.started, 4, "four combinations started")
    for i, opts in ipairs(inj.started) do
        t.ok(type(opts.sink) == "table" and opts.sink.collector == c,
             ("combination %d's sink is the run's own collector"):format(i))
    end
    t.eq(writes, 4, "and four writes were made - one per trial, not two")
    RR.stop()
end

do
    -- Refused rather than ignored, as Sweep does: a caller passing a path
    -- believes the rows go there too.
    RR.stop()
    local ok, why = RR.start({ route = ROUTE, collector = collector(),
                               injector = injector({}), delays = { 4 },
                               sink = { path = "x.jsonl" } })
    t.is_nil(ok, "a route run given a sink as well as a collector does not start")
    t.ok(tostring(why):find("second writer") ~= nil, tostring(why))
    t.eq(RR.running(), false, "and nothing is left running")
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
    t.ok(tostring(p.problem_detail[1].detail):find("disk said no") ~= nil,
         "with the reason the write reported: " .. tostring(p.problem_detail[1].detail))
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

-- --- the files on offer --------------------------------------------------------

t.group("list_routes: the panel's picker, not two hard-coded paths")

do
    local asked = nil
    local files = {
        "reframework/data/ComboExplorer_data/route/zangief-modern-max-damage-2.json",
        -- A backslash separator, as fs.glob reports one on Windows.
        "reframework/data/ComboExplorer_data/route\\zangief-modern-max-damage-1.json",
        "reframework/data/ComboExplorer_data/route/zangief-modern-no-gauge-1.json",
        "reframework/data/ComboExplorer_data/route/ground-truth.json",
        "reframework/data/ComboExplorer_data/route/ground-truth-ab.json",
        "reframework/data/ComboExplorer_data/route/ryu-modern-max-damage-1.json",
        "reframework/data/ComboExplorer_data/route/notes.txt",
    }
    local list, note = RR.list_routes("ComboExplorer_data/route", "Zangief", "modern", {
        glob = function(p) asked = p return files end,
    })
    t.is_nil(note, "a listing that worked carries no note")
    t.eq(asked, "ComboExplorer_data\\\\route\\\\.*json",
         "the glob has two backslashes per separator at runtime, like Sweep.list_worklists")

    local names = {}
    for i, e in ipairs(list) do names[i] = e.name end
    t.eq_list(names, {
        "zangief-modern-max-damage-1.json",
        "zangief-modern-max-damage-2.json",
        "zangief-modern-no-gauge-1.json",
        "ground-truth-ab.json",
        "ground-truth.json",
        "ryu-modern-max-damage-1.json",
    }, "this character's plan routes by plan then rank, then everything else by name; not the .txt")

    t.eq(list[1].kind, "plan", "a generated file is recognised by its name")
    t.eq(list[1].plan_name, "max-damage", "with the plan it came from")
    t.eq(list[1].rank, 1, "and the rank")
    t.ok(list[1].label:find("max-damage", 1, true) ~= nil, "which the label says: " .. list[1].label)
    t.eq(list[1].path, "ComboExplorer_data/route/zangief-modern-max-damage-1.json",
         "the path is rebuilt from the directory the panel passed, whatever separators glob reported")
    t.eq(list[4].kind, "named", "a hand-written route is offered too")
    t.eq(list[4].label, "ground-truth-ab", "under its own name")
    t.eq(list[6].kind, "named",
         "another character's file is listed, not labelled as this character's plan")

    local none, why = RR.list_routes("ComboExplorer_data/route", "zangief", "modern", {})
    t.eq(#none, 0, "a machine that cannot list gets nothing, and says so")
    t.ok(tostring(why):find("fs.glob") ~= nil, tostring(why))

    local boom, bwhy = RR.list_routes("ComboExplorer_data/route", "zangief", "modern",
                                      { glob = function() error("listing exploded") end })
    t.eq(#boom, 0, "a listing that raises does not take the panel down")
    t.ok(tostring(bwhy):find("could not list") ~= nil, tostring(bwhy))
end

t.group("describe_route: read once, and a bad file stays listed")

do
    local reads = 0
    local docs = {
        ["a.json"] = { schema = "ce.route.v1", id = "r", character = "Zangief",
                       control_scheme = "modern",
                       steps = { { action_id = 1, input_method = "manual", notation = "a" },
                                 { action_id = 2, input_method = "manual", notation = "b" },
                                 { action_id = 3, input_method = "manual", notation = "c" } },
                       delays = { { 40, 44 }, { 2, 4, 6 } },
                       gaps = { { source = "measured" }, { source = "predicted" } } },
        ["b.json"] = { schema = "ce.route.v1", id = "one",
                       steps = { { action_id = 1, input_method = "manual", notation = "a" } } },
    }
    local io_ = { load = function(path)
        reads = reads + 1
        local base = path:match("([^/]+)$")
        if base == "boom.json" then error("disk on fire") end
        return docs[base]
    end }

    local e = RR.describe_route({ path = "d/a.json" }, io_)
    t.eq(e.steps, 3, "the step count")
    t.eq(e.gaps, 2, "the number of gaps")
    t.eq(e.combinations, 6, "and the grid core/Route.delay_grid would run")
    t.eq(e.gap_sources, "measured, predicted",
         "where each gap's delays came from, as plan.lua wrote it")
    t.eq(e.character, "Zangief", "and who the file says it is for")
    RR.describe_route(e, io_)
    t.eq(reads, 1, "a described entry is not read again: the panel draws every frame")

    local bad = RR.describe_route({ path = "d/b.json" }, io_)
    t.ok(tostring(bad.error):find("two steps") ~= nil,
         "a file core/Route.build refuses stays in the list with the refusal on it: "
         .. tostring(bad.error))
    t.is_nil(bad.steps, "and offers no step count")

    local missing = RR.describe_route({ path = "d/c.json" }, io_)
    t.ok(tostring(missing.error):find("readable") ~= nil, tostring(missing.error))

    local boom = RR.describe_route({ path = "d/boom.json" }, io_)
    t.ok(tostring(boom.error):find("could not be read") ~= nil,
         "a reader that raises does not take the panel down: " .. tostring(boom.error))
end

return t.finish()
