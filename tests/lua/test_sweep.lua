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
local function injector(outcomes)
    local state = { started = {}, delays = {}, delay = {},
                    ticks = 0, running = false, n = 0, recorded = 0 }
    local cur = nil
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
            cur = plan
            state.running = true
            return true
        end,
        tick = function()
            state.ticks = state.ticks + 1
            state.running = false          -- one tick per trial, for the test
            return { outcome = cur.outcome or "judged" }
        end,
        stop = function() state.running = false cur = nil end,
        result = function()
            return { outcome = cur and cur.outcome,
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

return t.finish()
