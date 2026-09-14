-- Unit tests for func/ComboExplorer/runtime/Sweep.lua
--
-- This is the module that makes "start it and walk away" true, so the things
-- worth pinning are the ones that would turn a night into nothing: a pair that
-- comes back forever, a sweep that keeps going while nothing is being measured,
-- and work that is repeated because the resume did not take.
--
-- The injector is a table. Nothing here touches a game.

local t = require("tests.lua.harness")
local Sweep = require("func/ComboExplorer/runtime/Sweep")
local ResultCollector = require("func/ComboExplorer/core/ResultCollector")

-- --- a fake game -------------------------------------------------------------

-- outcomes : per start, what that trial will do. An entry is
--   { outcome = "judged", retryable = false }  or  { refuse = "why" }
--
-- It keeps the real Injector's contract about the result (#45): the row is
-- written through the sink it was started with, on the tick the outcome
-- arrives, and result() says whether it landed. Sweep writes nothing itself,
-- so a fake that did not write would make every sweep look empty - and a fake
-- that let Sweep write would hide a second writer.
local function injector(outcomes)
    local state = { started = {}, delays = {}, delay = {}, sinks = {},
                    ticks = 0, running = false, n = 0, recorded = 0 }
    local cur = nil
    local record_error = nil
    local api
    api = {
        log = state,
        running = function() return state.running end,
        start = function(opts)
            state.n = state.n + 1
            local plan = outcomes[state.n] or { outcome = "judged" }
            if plan.refuse then return nil, plan.refuse end
            state.started[#state.started + 1] = opts.edge_id
            state.delays[#state.delays + 1] = opts.delays
            state.delay[#state.delay + 1] = opts.delay
            state.sinks[#state.sinks + 1] = opts.sink
            cur = plan
            record_error = nil
            state.running = true
            return true
        end,
        tick = function()
            state.ticks = state.ticks + 1
            state.running = false          -- one tick per trial, for the test
            local spec = api.record()
            local sink = state.sinks[#state.sinks]
            if spec and sink and sink.collector then
                if cur.append_fails then
                    record_error = "append: " .. cur.append_fails
                else
                    local rec, problems = ResultCollector.write(sink.collector, spec)
                    if not rec then
                        record_error = tostring(problems and problems[1]
                                                and problems[1].problem)
                    end
                end
            end
            return { outcome = cur.outcome or "judged" }
        end,
        stop = function() state.running = false cur = nil end,
        result = function()
            return { outcome = cur and cur.outcome,
                     record_error = record_error,
                     trial = { retryable = cur and cur.retryable or false } }
        end,
        record = function()
            state.recorded = state.recorded + 1
            if cur and cur.no_record then return nil end
            return {
                subject = { kind = "edge", id = state.started[#state.started] },
                edge_id = state.started[#state.started],
                attempt = 1,
                verdict = cur and cur.verdict or "link",
                delay = 4,
                evidence = { judge_gap = 1 },
                provenance = { calibration_id = "cal-test", game_patch = "p" },
            }
        end,
    }
    return api
end

local function worklist(n, over)
    local pairs_ = {}
    for i = 1, n do
        pairs_[i] = { a_id = 600 + i, a_method = "manual", a_notation = "A",
                      b_id = 700 + i, b_method = "manual", b_notation = "B",
                      confidence = "high" }
    end
    local wl = {
        schema = "ce.worklist.v1", character = "Zangief", control_scheme = "modern",
        ac_sha256 = "aaa", bcm_sha256 = "bbb", count = n, pairs = pairs_,
    }
    for k, v in pairs(over or {}) do wl[k] = v end
    return wl
end

local function collector(over)
    local written = {}
    local c = ResultCollector.new({
        append = function(line) written[#written + 1] = line return true end,
        encode = function(rec) return "{" .. tostring(rec.edge_id) .. "}" end,
        identity = { calibration_id = "cal-test", game_patch = "p" },
        resume = over and over.resume or nil,
        decode = over and over.decode or nil,
    })
    return c, written
end

local function drive(n)
    for _ = 1, (n or 200) do
        local p = Sweep.progress()
        if not p or p.done then break end
        Sweep.tick()
    end
end

-- --- the worklist is checked before anything runs -----------------------------

t.group("a worklist is a list of action ids, and ids belong to one catalog")

do
    local ok, why = Sweep.identity_matches(worklist(1), { ac_sha256 = "aaa", bcm_sha256 = "bbb" })
    t.eq(ok, true, "matching checksums pass: " .. tostring(why))

    local nope, reason = Sweep.identity_matches(worklist(1),
        { ac_sha256 = "zzz", bcm_sha256 = "bbb" })
    t.eq(nope, false, "a different catalog is refused")
    t.ok(tostring(reason):find("ac_sha256") ~= nil,
         "naming which half disagrees: " .. tostring(reason))

    -- Silence is not a mismatch. A catalog with no checksum recorded has not
    -- claimed to be a different one.
    t.eq(Sweep.identity_matches(worklist(1), {}), true,
         "a catalog with no checksums is not treated as a wrong one")
end

do
    Sweep.stop()
    local c = collector()
    local nope, why = Sweep.start({
        worklist = worklist(2), collector = c,
        catalog = { ac_sha256 = "different", bcm_sha256 = "bbb" },
        injector = injector({}),
    })
    t.is_nil(nope, "a sweep will not start against the wrong catalog")
    t.ok(tostring(why):find("different catalog") ~= nil, "and says so: " .. tostring(why))
end

do
    Sweep.stop()
    local nope, why = Sweep.start({ worklist = worklist(2), injector = injector({}) })
    t.is_nil(nope, "and it will not start with no collector")
    t.ok(tostring(why):find("did not happen") ~= nil, "for the stated reason: " .. tostring(why))
end

do
    local nope, why = Sweep.load_worklist("nope/does/not/exist.json")
    t.is_nil(nope, "a missing worklist is a refusal")
    t.ok(tostring(why):find("explore.lua") ~= nil,
         "that says how to make one: " .. tostring(why))

    local wrong, wwhy = Sweep.load_worklist("x.json", {
        load = function() return { schema = "ce.route.v1" } end })
    t.is_nil(wrong, "and so is a document that is not a worklist")
    t.ok(tostring(wwhy):find("not a worklist") ~= nil, tostring(wwhy))
end

-- --- which worklist the panel offers ---------------------------------------------

t.group("the SWEEP panel's worklist choice: this character's files, in a fixed order")

do
    local asked = nil
    -- Backslashes and a shuffled order, the way a Windows listing might come back.
    local listing = {
        "ComboExplorer_data\\worklist\\zangief-modern-plan-starter-chu.json",
        "ComboExplorer_data\\worklist\\zangief-modern-drc.json",
        "ComboExplorer_data\\worklist\\ryu-modern.json",
        "ComboExplorer_data\\worklist\\zangief-classic.json",
        "ComboExplorer_data\\worklist\\zangief-classic-plan-max-damage.json",
        "ComboExplorer_data\\worklist\\zangief-modern-plan-max-damage.json",
        "ComboExplorer_data\\worklist\\zangief-modern.json",
        "ComboExplorer_data\\worklist\\zangief-modern-old.json",
        "ComboExplorer_data\\worklist\\zangief-modern.json.bak",
        "ComboExplorer_data\\worklist\\zangief-modern-plan-.json",
        "ComboExplorer_data\\worklist\\zangiefx-modern.json",
        "ComboExplorer_data\\worklist\\zangief-modern-plan-no-gauge.json",
    }
    local fs_ = { glob = function(pattern) asked = pattern return listing end }
    local list, note = Sweep.list_worklists("ComboExplorer_data/worklist", "Zangief", "modern", fs_)

    t.is_nil(note, "a listing that worked carries no note")
    t.eq(asked, "ComboExplorer_data\\\\worklist\\\\.*json",
         "the glob has two backslashes per separator at runtime, like CatalogLocator.GLOB")
    local names = {}
    for i, e in ipairs(list) do names[i] = e.name end
    t.eq_list(names, {
        "zangief-modern.json",
        "zangief-modern-plan-max-damage.json",
        "zangief-modern-plan-no-gauge.json",
        "zangief-modern-plan-starter-chu.json",
        "zangief-modern-drc.json",
    }, "all first, plans by name, drc last; other characters, schemes and odd names left out")

    local kinds = {}
    for i, e in ipairs(list) do kinds[i] = e.kind end
    t.eq_list(kinds, { "all", "plan", "plan", "plan", "drc" }, "each says its kind")
    t.eq(list[1].path, "ComboExplorer_data/worklist/zangief-modern.json",
         "the all-pairs path is spelled exactly as the panel always spelled it")
    t.eq(list[2].plan_name, "max-damage", "a plan's name is the part after -plan-")
    t.is_nil(list[1].plan_name, "and only a plan has one")
    t.ok(list[2].label:find("max-damage", 1, true) ~= nil, "the label names the plan: " .. list[2].label)
    t.is_nil(list[1].missing, "the all-pairs file was in the listing")
end

do
    local only_plan = { "ComboExplorer_data/worklist/zangief-modern-plan-x.json" }
    local list = Sweep.list_worklists("ComboExplorer_data/worklist", "zangief", "modern",
                                      { glob = function() return only_plan end })
    t.eq(#list, 2, "with no all-pairs file the default entry is still offered")
    t.eq(list[1].kind, "all", "first")
    t.eq(list[1].missing, true, "and marked missing, so load_worklist gets to say how to make one")

    local none, why = Sweep.list_worklists("ComboExplorer_data/worklist", "zangief", "modern", {})
    t.eq(#none, 1, "a machine that cannot list still gets today's one file")
    t.eq(none[1].path, "ComboExplorer_data/worklist/zangief-modern.json", "the same path as before")
    t.ok(tostring(why):find("fs.glob") ~= nil, "and says why nothing else is offered: " .. tostring(why))

    local boom, bwhy = Sweep.list_worklists("ComboExplorer_data/worklist", "zangief", "modern",
                                            { glob = function() error("listing exploded") end })
    t.eq(#boom, 1, "a listing that raises does not take the panel down")
    t.ok(tostring(bwhy):find("could not list") ~= nil, tostring(bwhy))
end

t.group("what is in each listed worklist is read once, and a bad file stays listed")

do
    local reads = {}
    local docs = {
        ["d/zangief-modern.json"] = worklist(3),
        ["d/zangief-modern-plan-no-gauge.json"] = worklist(2, {
            plan = { name = "no-gauge", conditions = { no_gauge = true, max_drive_bars = 2 },
                      sort = "scaled_damage", top = 20 } }),
        ["d/zangief-modern-plan-max-damage.json"] = worklist(1, {
            plan = { name = "max-damage", conditions = {} } }),
        ["d/zangief-modern-plan-broken.json"] = nil,                 -- malformed
        ["d/zangief-modern-plan-route.json"] = { schema = "ce.route.v1" },
        ["d/zangief-modern-plan-empty.json"] = worklist(0),
        ["d/zangief-modern-plan-classic.json"] = worklist(1, { control_scheme = "classic" }),
    }
    local listing = {}
    for p in pairs(docs) do listing[#listing + 1] = p end
    listing[#listing + 1] = "d/zangief-modern-plan-broken.json"
    listing[#listing + 1] = "d/zangief-modern-plan-raises.json"
    local io_ = {
        load = function(path)
            reads[path] = (reads[path] or 0) + 1
            if path:find("raises") then error("disk on fire") end
            return docs[path]
        end,
    }
    local list = Sweep.list_worklists("d", "zangief", "modern",
                                      { glob = function() return listing end })
    local by = {}
    for _, e in ipairs(list) do
        Sweep.describe_worklist(e, io_)
        Sweep.describe_worklist(e, io_)       -- a second frame
        by[e.plan_name or e.kind] = e
    end
    t.eq(#list, 8, "every file for this character is listed, readable or not")
    t.eq(reads["d/zangief-modern.json"], 1, "each file is read once, not per frame")
    t.eq(by.all.count, 3, "the pair count comes from the file")
    t.is_nil(by.all.error, "a good file has no error")
    t.is_nil(by.all.conditions, "the all-pairs list has no conditions line")
    t.eq(by["no-gauge"].count, 2, "a plan's count")
    t.eq(by["no-gauge"].conditions, "max_drive_bars=2, no_gauge",
         "its conditions as one sorted line")
    t.eq(by["no-gauge"].sort, "scaled_damage", "and what it was ranked by")
    t.ok(tostring(by["max-damage"].conditions):find("none") ~= nil,
         "a plan with no conditions says so: " .. tostring(by["max-damage"].conditions))
    t.ok(tostring(by.broken.error):find("could not be read") ~= nil,
         "a malformed file is listed with an error: " .. tostring(by.broken.error))
    t.ok(tostring(by.raises.error):find("disk on fire") ~= nil,
         "a reader that raises is caught and reported: " .. tostring(by.raises.error))
    t.ok(tostring(by.route.error):find("not a worklist") ~= nil,
         "a document that is not a worklist: " .. tostring(by.route.error))
    t.ok(tostring(by.empty.error):find("no pairs") ~= nil,
         "an empty worklist: " .. tostring(by.empty.error))
    t.ok(tostring(by.classic.mismatch):find("classic") ~= nil,
         "a file whose own scheme disagrees with its name is flagged: "
         .. tostring(by.classic.mismatch))
    t.is_nil(by.classic.error, "as a warning, not an error")
    t.is_nil(by["no-gauge"].mismatch, "and a file that agrees is not")
end

-- --- the ordinary pass ---------------------------------------------------------

t.group("a whole worklist, unattended")

do
    Sweep.stop()
    local inj = injector({})
    local c, written = collector()
    t.ok(Sweep.start({ worklist = worklist(5), collector = c, injector = inj,
                       delay = 4, allow_injection = true }))
    drive()

    local r = Sweep.result()
    t.eq(r.done, true, "the sweep finishes")
    t.eq(r.finished, 5, "having run every pair")
    t.eq(#written, 5, "and written one line each")
    t.ok(tostring(r.stopped_because):find("finished") ~= nil,
         "saying why it stopped: " .. tostring(r.stopped_because))
    t.eq(#inj.log.started, 5, "the injector was started once per pair")
    Sweep.stop()
end

-- --- one writer ----------------------------------------------------------------

t.group("the sweep's collector is the trial's sink, and nothing writes twice")

-- #45. The Injector's sink used to be opened and never written, so Sweep wrote
-- each row itself - while the panel passed the same file to the Injector as
-- its sink. The day the sink started writing, every row would have gone in
-- twice. Now the collector IS the sink and Sweep only reads whether the row
-- landed.

do
    Sweep.stop()
    local inj = injector({})
    local c, written = collector()
    Sweep.start({ worklist = worklist(3), collector = c, injector = inj,
                  delay = 4, allow_injection = true })
    drive()
    t.eq(#inj.log.sinks, 3, "every trial was handed a sink")
    for i, sink in ipairs(inj.log.sinks) do
        t.ok(type(sink) == "table" and sink.collector == c,
             ("trial %d's sink is the sweep's own collector"):format(i))
        t.is_nil(sink.path, "and not a second file beside it")
    end
    t.eq(#written, 3, "three trials, three lines - the sweep did not add its own")
    Sweep.stop()
end

do
    Sweep.stop()
    -- The panel used to pass a path here. Ignoring it would leave a caller
    -- believing the rows go somewhere they do not.
    local c = collector()
    local nope, why = Sweep.start({ worklist = worklist(1), collector = c,
                                    injector = injector({}), delay = 4,
                                    sink = { path = "x.jsonl" } })
    t.is_nil(nope, "a sweep given a sink as well as a collector does not start")
    t.ok(tostring(why):find("second writer") ~= nil,
         "because that is a second writer: " .. tostring(why))
    t.eq(Sweep.running(), false, "and nothing is left running")
end

do
    Sweep.stop()
    -- A row that did not land is a problem on the sweep, not a silent hole:
    -- the pair has not been answered, whatever its verdict was.
    local inj = injector({ [2] = { outcome = "judged", append_fails = "the disk is full" } })
    local c, written = collector()
    Sweep.start({ worklist = worklist(3), collector = c, injector = inj,
                  delay = 4, allow_injection = true })
    drive()
    local r = Sweep.result()
    t.eq(r.finished, 3, "the sweep carries on past one failed write")
    t.eq(#written, 2, "with the other two rows on file")
    local found = nil
    for _, pr in ipairs(r.problem_detail or {}) do
        if tostring(pr.reason):find("would not record") then found = pr end
    end
    t.ok(found ~= nil, "the failed write is recorded as a problem")
    t.ok(found and tostring(found.detail):find("disk is full") ~= nil,
         "carrying the Injector's own reason: " .. tostring(found and found.detail))
    Sweep.stop()
end

-- --- a pair that asks to come back ---------------------------------------------

t.group("a retryable pair comes back, but not forever")

do
    Sweep.stop()
    -- Every trial says it was inconclusive and retryable.
    local always = setmetatable({}, { __index = function()
        return { outcome = "abandoned", retryable = true }
    end })
    local inj = injector(always)
    local c = collector()
    t.ok(Sweep.start({ worklist = worklist(2), collector = c, injector = inj, delay = 4,
                       max_attempts = 3, allow_injection = true }))
    drive(500)

    local r = Sweep.result()
    t.eq(r.done, true, "it still finishes")
    -- Two pairs, three attempts each. Without the bound this never terminates,
    -- and an infinite loop over one pair looks exactly like progress.
    t.eq(#inj.log.started, 6, "each pair was tried max_attempts times (" .. #inj.log.started .. ")")
    local gave_up = 0
    for _, pr in ipairs(r.problem_detail or {}) do
        if tostring(pr.reason):find("gave up") then gave_up = gave_up + 1 end
    end
    t.eq(gave_up, 2, "and both are recorded as given up on rather than dropped")
    Sweep.stop()
end

do
    Sweep.stop()
    -- Requeued pairs go after the whole list, not straight back in. Whatever
    -- made one inconclusive has a better chance of having passed by then.
    local inj = injector({ [1] = { outcome = "abandoned", retryable = true } })
    local c = collector()
    Sweep.start({ worklist = worklist(3), collector = c, injector = inj,
                  delay = 4, allow_injection = true })
    drive()
    local order = inj.log.started
    t.ok(#order >= 4, "the retried pair ran again (" .. #order .. " starts)")
    t.eq(order[1], order[#order], "and it ran LAST, after the rest of the list")
    t.ok(order[2] ~= order[1], "rather than immediately again")
    Sweep.stop()
end

-- --- nothing is being measured --------------------------------------------------

t.group("a sweep that cannot start a trial stops instead of spinning")

do
    Sweep.stop()
    local refusing = setmetatable({}, { __index = function()
        return { refuse = "injection is blocked until these are measured: modern_button_bits" }
    end })
    local inj = injector(refusing)
    local c = collector()
    Sweep.start({ worklist = worklist(50), collector = c, injector = inj,
                  delay = 4, max_start_failures = 4, allow_injection = true })
    drive(500)

    local r = Sweep.result()
    t.eq(r.done, true, "it gives up")
    t.eq(r.started, 0, "having measured nothing")
    t.ok(tostring(r.stopped_because):find("would not start") ~= nil,
         "and says that is why: " .. tostring(r.stopped_because))
    t.ok(tostring(r.stopped_because):find("modern_button_bits") ~= nil,
         "carrying the injector's own reason, so the fix is visible")
    t.ok(r.start_failures <= 5, "without burning the whole list first (" .. r.start_failures .. ")")
    Sweep.stop()
end

do
    Sweep.stop()
    -- One refusal in the middle is not the end. The counter is CONSECUTIVE
    -- failures; a single blip must not stop a night's work.
    local plans = { [2] = { refuse = "a blip" } }
    local inj = injector(setmetatable(plans, { __index = function() return {} end }))
    local c = collector()
    Sweep.start({ worklist = worklist(4), collector = c, injector = inj,
                  delay = 4, max_start_failures = 3, allow_injection = true })
    drive()
    local r = Sweep.result()
    t.eq(r.done, true, "the sweep completes")
    t.ok(tostring(r.stopped_because):find("finished") ~= nil,
         "normally, not by giving up: " .. tostring(r.stopped_because))
    t.eq(r.start_failures, 1, "with the blip counted")
    Sweep.stop()
end

do
    Sweep.stop()
    -- Non-consecutive blips must not add up. The counter is CONSECUTIVE
    -- failures, and the assertion that pins it needs MORE blips than the bound
    -- with a success between them - written with one blip and a bound of three,
    -- this passed with the reset deleted.
    local plans = { [2] = { refuse = "blip one" }, [5] = { refuse = "blip two" } }
    local inj = injector(setmetatable(plans, { __index = function() return {} end }))
    local c = collector()
    Sweep.start({ worklist = worklist(6), collector = c, injector = inj,
                  delay = 4, max_start_failures = 2, allow_injection = true })
    drive()
    local r = Sweep.result()
    t.eq(r.start_failures, 2, "both blips were counted")
    t.ok(tostring(r.stopped_because):find("finished") ~= nil,
         "and the sweep still finished, because they were not consecutive: "
         .. tostring(r.stopped_because))
    t.eq(r.finished, 4, "the other four pairs ran")
    Sweep.stop()
end

do
    Sweep.stop()
    -- The nastiest failure available here, and nothing asserted it. With no
    -- delay the collector cannot build a key, every claim is refused, every
    -- pair counts as skipped, and the sweep reports itself FINISHED having
    -- pressed nothing - a night that looks like a completed pass.
    local c = collector()
    local nope, why = Sweep.start({ worklist = worklist(3), collector = c,
                                    injector = injector({}), allow_injection = true })
    t.is_nil(nope, "a sweep with no delay does not start")
    t.ok(tostring(why):find("delay") ~= nil, "saying it is the delay: " .. tostring(why))
    t.ok(tostring(why):find("pressed nothing") ~= nil,
         "and what would have happened instead")

    -- A list of delays is the other accepted form.
    t.ok(Sweep.start({ worklist = worklist(1), collector = c, injector = injector({}),
                       delays = { 4 }, allow_injection = true }) ~= nil,
         "while a delay list is accepted")
    Sweep.stop()
end

do
    Sweep.stop()
    -- ACCEPTED IS NOT USED. The assertion above - that a delay list starts a
    -- sweep - was the only one there was, and it passed while `delays` was
    -- stored and then never read again: every trial ran on the nil scalar, so
    -- the collector could not build a key, every claim was refused, every pair
    -- counted as skipped, and the sweep reported itself finished having pressed
    -- nothing. Accepted, recorded as accepted, and silently ignored.
    local inj = injector({})
    local c = collector()
    t.ok(Sweep.start({ worklist = worklist(3), collector = c, injector = inj,
                       delays = { 5 }, allow_injection = true }))
    drive()

    local r = Sweep.result()
    t.eq(r.finished, 3, "with a delay LIST, the pairs actually run")
    t.eq(r.skipped, 0, "none of them is skipped for want of a key")
    t.eq(#inj.log.started, 3, "and the injector was started for each")
    t.eq_list(inj.log.delays[1], { 5 }, "the list reached the injector unchanged")
    Sweep.stop()
end

-- --- resume ----------------------------------------------------------------------

t.group("work already done is not done again")

do
    Sweep.stop()
    -- A previous run's file. The collector owns reading it; this asserts that
    -- the sweep asks before it presses anything, which is the part that saves
    -- the evening after a crash.
    -- Built through ResultCollector.trial so it is a record the schema
    -- accepts: index() validates every line and files an invalid one as a
    -- problem rather than as work already done, so a hand-written record here
    -- would silently prove nothing.
    local prior_rec = ResultCollector.trial({
        edge_id = "601:manual->701:manual", attempt = 1, verdict = "link", delay = 4,
        evidence = { judge_gap = 1 },
        provenance = { calibration_id = "cal-test", game_patch = "p" },
    })
    t.ok(prior_rec ~= nil, "the previous run's record is a valid trial record")

    -- The trailing newline matters and is not decoration: an unterminated last
    -- line is treated as "ran but lost the result" rather than as done, so
    -- without it this would be re-run rather than skipped.
    local prior = require("tools.lua.json").encode(prior_rec) .. string.char(10)

    local c = ResultCollector.new({
        append = function() return true end,
        encode = function(rec) return "{}" end,
        identity = { calibration_id = "cal-test", game_patch = "p" },
        resume = prior,
        decode = function(text) return require("tools.lua.json").decode(text) end,
    })
    t.ok(c ~= nil, "a collector resumes from the previous file")

    local inj = injector({})
    Sweep.start({ worklist = worklist(3), collector = c, injector = inj,
                  delay = 4, allow_injection = true })
    drive()

    local r = Sweep.result()
    t.eq(r.skipped, 1, "the pair already answered is skipped")
    t.eq(#inj.log.started, 2, "and only the other two were pressed")
    for _, id in ipairs(inj.log.started) do
        t.ok(id ~= "601:manual->701:manual", "the answered pair was not pressed again")
    end
    Sweep.stop()
end

-- --- lifecycle --------------------------------------------------------------------

t.group("one sweep at a time")

do
    Sweep.stop()
    local c = collector()
    t.ok(Sweep.start({ worklist = worklist(1), collector = c, delay = 4,
                       injector = injector({}) }))
    local second, why = Sweep.start({ worklist = worklist(1), collector = c,
                                      delay = 4, injector = injector({}) })
    t.is_nil(second, "a second sweep does not start on top of the first")
    t.ok(tostring(why):find("already running") ~= nil, tostring(why))
    Sweep.stop()
    t.eq(Sweep.running(), false, "stopping clears it")
    t.is_nil(Sweep.progress(), "and there is nothing to report")
end


-- =========================================================
t.group("the gap comes from the frame data, not from a default")

-- #46, measured on build 24176760. Every pair used to run at the panel's
-- delay of 4, because that was all there was. At gap 4 the second input lands
-- inside the first move's animation - a cancel window - and the 202 rows that
-- produced found 8 links, ALL of them Super Arts, which are the only thing
-- that connects out of one. One real pair's link window was gap 40..44.

local Sweep2 = require("func/ComboExplorer/runtime/Sweep")

do
    -- The numbers are the measured pair: Zangief 6HP into 3MP.
    local p = { a_startup = 14, a_active = "5", a_recovery = 15, a_hitstop = 13,
                a_hitstun = 28, b_startup = 7 }
    local delay, why = Sweep2.delay_for(p, { hold_ticks = 3, buffer_ticks = 4, delay = 4 })
    t.eq(delay, 44, "the gap is where A has just become free - measured, 44 linked")
    t.eq(why.predicted, true, "and the row can say it was predicted")
    t.ok(why.window ~= nil, "carrying the window it came from")
end

do
    -- A pair the frame data is short on still runs, at whatever the operator
    -- set - and says the gap was NOT predicted. A negative measured at an
    -- unpredicted gap is not evidence that the pair does not link, and a row
    -- that cannot say which it was is not readable later.
    local p = { a_startup = 14, b_startup = 7 }
    local delay, why = Sweep2.delay_for(p, { hold_ticks = 3, buffer_ticks = 4, delay = 4 })
    t.eq(delay, 4, "it falls back to the operator's delay")
    t.eq(why.predicted, false, "and says so")
    t.ok(#why.missing > 0, "naming what the frame data was missing")
end

do
    -- No buffer measured: there is no window, and the fallback is the same.
    -- The buffer is unverified and this is the one place that would quietly
    -- turn it into a number.
    local p = { a_startup = 14, a_active = "5", a_recovery = 15, a_hitstop = 13,
                a_hitstun = 28, b_startup = 7 }
    local _, why = Sweep2.delay_for(p, { hold_ticks = 3, delay = 4 })
    t.eq(why.predicted, false, "no buffer, no prediction")
end


t.group("pairs the compiler cannot play are set aside before the first trial (#49)")

do
    Sweep.stop()
    local MID = "\228\184\173"   -- 中
    local wl = worklist(4)
    wl.pairs[1].a_notation, wl.pairs[1].b_notation = "2 + " .. MID, "22 + " .. MID
    wl.pairs[2].a_notation, wl.pairs[2].b_notation = "2 + " .. MID, "> " .. MID
    wl.pairs[3].a_notation, wl.pairs[3].b_notation = "2 + " .. MID, "236236 + " .. MID
    local inj = injector({})
    local c = collector()
    local ok, err = Sweep.start({ worklist = wl, collector = c, injector = inj,
                                  delay = 4, allow_injection = true })
    t.ok(ok, "the sweep still starts: " .. tostring(err))
    drive(50)

    local r = Sweep.result()
    t.eq(r.unplayable, 2, "the 22 pair and the follow-up pair are set aside")
    t.eq(r.unplayable_by_kind["repeat"], 1, "counted by kind")
    t.eq(r.unplayable_by_kind.followup_context, 1, "both kinds")
    t.eq(r.total, 2, "and the pair total says the list is shorter, not truncated")
    t.eq(#inj.log.started, 2, "neither of them was pressed")
    for _, id in ipairs(inj.log.started) do
        t.ok(id ~= "601:manual->701:manual" and id ~= "602:manual->702:manual",
             "no trial ran for a set-aside pair: " .. id)
    end
    t.eq(r.start_failures, 0, "and they are not start failures, which would end the sweep")
    t.eq(r.unplayable_detail[1].pair, "601:manual->701:manual", "each is listed by pair")
    t.ok(tostring(r.unplayable_detail[1].reason):find("twice in a row") ~= nil,
         "with its reason")
    t.eq(#wl.pairs, 4, "the caller's worklist is not edited")
    Sweep.stop()
end

t.group("a follow-up pair whose parent the frame data names is played, not set aside")

do
    -- explore.lua writes context_known = true on exactly the follow-up pairs
    -- whose parent the frame source names - Zangief's MP into ">MP", because
    -- the source spells that move "5MP~MP". The sweep has to take that as the
    -- vouch SequenceCompiler.unplayable asks for, or the only two follow-up
    -- pairs that are real get set aside with the 54 that are not.
    Sweep.stop()
    local MID = "\228\184\173"   -- 中
    local wl = worklist(3)
    wl.pairs[1].a_notation, wl.pairs[1].b_notation = MID, "> " .. MID
    wl.pairs[1].context_dependent, wl.pairs[1].context_known = true, true
    -- The same follow-up without the vouch: still set aside.
    wl.pairs[2].a_notation, wl.pairs[2].b_notation = "2 + " .. MID, "> " .. MID
    wl.pairs[2].context_dependent = true
    -- Anything other than true is not a vouch, however truthy.
    wl.pairs[3].a_notation, wl.pairs[3].b_notation = "2 + " .. MID, "> " .. MID
    wl.pairs[3].context_dependent, wl.pairs[3].context_known = true, "true"
    local inj = injector({})
    local c = collector()
    local ok, err = Sweep.start({ worklist = wl, collector = c, injector = inj,
                                  delay = 4, allow_injection = true })
    t.ok(ok, "the sweep starts: " .. tostring(err))
    drive(50)

    local r = Sweep.result()
    t.eq(r.unplayable, 2, "only the two pairs nobody vouched for are set aside")
    t.eq(r.unplayable_by_kind.followup_context, 2, "both as follow-ups without context")
    t.eq(r.total, 1, "leaving the vouched pair in the list")
    t.eq(#inj.log.started, 1, "and it is the one that is pressed")
    t.eq(inj.log.started[1], "601:manual->701:manual", "the parent-confirmed pair ran")
    Sweep.stop()
end

t.group("a Drive Rush Cancel pair is set aside as drive_rush, and the direct pair still runs")

do
    -- Built by hand in the shape the -drc worklist carries: a normal pair plus
    -- via, the on-hit margin through the rush, and the rush's cost.
    Sweep.stop()
    local MID = "\228\184\173"   -- 中
    local wl = worklist(1)
    local direct = wl.pairs[1]
    direct.a_notation, direct.b_notation = "2 + " .. MID, "236236 + " .. MID
    -- Frames on the pair, so delay_for WOULD predict a gap if anything asked it.
    direct.a_startup, direct.a_active, direct.a_recovery = 5, 3, 10
    direct.b_startup = 4
    local drc = {}
    for k, v in pairs(direct) do drc[k] = v end
    drc.via, drc.a_drc_on_hit, drc.drc_margin_frames, drc.drive_cost =
        "drive_rush_cancel", 11, 7, 30000
    -- And a DRC pair whose A would also be refused as a repeat: still counted
    -- as the rush, which is the refusal no fix to A gets round.
    local drc22 = {}
    for k, v in pairs(drc) do drc22[k] = v end
    drc22.a_id, drc22.a_notation = 699, "22 + " .. MID
    wl.pairs = { drc, direct, drc22 }
    wl.count = 3

    local inj = injector({})
    local c = collector()
    local ok, err = Sweep.start({ worklist = wl, collector = c, injector = inj,
                                  delay = 4, allow_injection = true })
    t.ok(ok, "a DRC worklist loads and the sweep starts: " .. tostring(err))
    drive(50)

    local r = Sweep.result()
    t.eq(r.unplayable, 2, "both DRC pairs are set aside")
    t.eq(r.unplayable_by_kind.drive_rush, 2, "as drive rush, both of them")
    t.is_nil(r.unplayable_by_kind["repeat"], "the one with a 22 in A is not counted as a repeat")
    t.eq(r.total, 1, "the direct pair is left in the list")
    t.eq(#inj.log.started, 1, "and it is the only one pressed")
    t.eq(inj.log.started[1], "601:manual->701:manual",
         "under the direct key, spelled as it always was")
    t.eq(r.unplayable_detail[1].pair, "601:manual->drc->701:manual",
         "the DRC pair's key is not the direct pair's")
    t.ok(r.unplayable_detail[1].pair ~= inj.log.started[1],
         "so resume can never read one as the other answered")
    t.ok(tostring(r.unplayable_detail[1].reason):find("Drive Rush Cancel") ~= nil,
         "with the reason the compiler gives: " .. tostring(r.unplayable_detail[1].reason))
    t.eq(r.predicted + r.unpredicted, 1, "a gap was decided for the direct pair only")
    t.eq(r.skipped, 0, "and no claim was made for a set-aside pair")
    t.eq(#wl.pairs, 3, "the caller's worklist is not edited")
    Sweep.stop()
end

t.group("a worklist of nothing but DRC pairs finishes without pressing anything")

do
    Sweep.stop()
    local wl = worklist(2)
    for _, p in ipairs(wl.pairs) do p.via, p.drive_cost = "drive_rush_cancel", 30000 end
    local inj = injector({})
    local ok, err = Sweep.start({ worklist = wl, collector = collector(), injector = inj,
                                  delay = 4, allow_injection = true })
    t.ok(ok, "it starts: " .. tostring(err))
    drive(20)
    local r = Sweep.result()
    t.eq(r.unplayable_by_kind.drive_rush, 2, "every pair set aside as drive rush")
    t.eq(#inj.log.started, 0, "nothing pressed")
    t.eq(r.done, true, "and it says it is done")
    t.eq(r.start_failures, 0, "not by failing to start")
    Sweep.stop()
end

return t.finish()
