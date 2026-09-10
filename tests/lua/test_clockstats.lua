-- Unit tests for func/ComboExplorer/core/ClockStats.lua
--
-- The case that matters most here is the one a review caught before the code
-- ever ran: a build where pl_input_sub fires exactly once per player per frame,
-- sampled across a round transition, reporting "more than one call per frame".
-- That is the exact opposite of the truth, and it would have been written to a
-- file and used to choose the delay unit for the whole project.
--
-- Everything below is really asking: can this instrument be made to lie?

local t = require("tests.lua.harness")
local CS = require("func/ComboExplorer/core/ClockStats")

local function frame(over)
    local f = { calls = { [0] = 1, [1] = 1 }, gate_open = true, paused = false, hitstop = false }
    for k, v in pairs(over or {}) do f[k] = v end
    return f
end

local function sample(n, over)
    local s = CS.new()
    for _ = 1, n do CS.add_frame(s, frame(over)) end
    return s
end

-- --- the clean case ----------------------------------------------------------

t.group("a clean sample")

local s = CS.new()
for i = 1, 400 do
    CS.add_frame(s, frame({ hitstop = (i % 40 == 0) }))
    CS.add_engine_frame(s, false)
end
local r = CS.report(s)

t.eq(r.frames.total, 400, "every frame counted")
t.eq(r.frames.included, 400, "and every frame usable")
t.eq(r.frames.with_hitstop, 10, "hitstop frames counted")
t.eq(r.tick_vs_engine_gap, 0, "the two clocks agree over the window")

local p1 = r.players["0"]
t.eq(#p1.calls_per_frame, 1, "one histogram bucket")
t.eq(p1.calls_per_frame[1].calls, 1, "of one call")
t.eq(p1.calls_per_frame[1].frames, 400, "on all 400 frames")
t.eq(p1.max_calls, 1, "max is one")

t.ok(r.assessment.usable, "the sample is fit to conclude from")

local finding = CS.calls_per_frame_finding(r, 0)
t.ok(finding.conclusive, "and the finding is conclusive")
t.eq(finding.calls_per_frame, 1, "one call per frame")

-- --- the failure the review caught ------------------------------------------

t.group("gate-closed frames must not become a zero bucket")

-- 560 observable frames plus 40 across a round transition where the injection
-- gate was shut. The callback cannot run on those, so a zero there means
-- "not observed", not "observed zero".
s = CS.new()
for _ = 1, 560 do CS.add_frame(s, frame({ hitstop = false })) end
for _ = 1, 20 do CS.add_frame(s, frame({ hitstop = true })) end
for _ = 1, 40 do CS.add_frame(s, frame({ gate_open = false, calls = {} })) end
r = CS.report(s)

t.eq(r.frames.total, 620, "all frames are accounted for")
t.eq(r.frames.included, 580, "but only the observable ones are included")
t.eq(r.frames.excluded_gate_closed, 40, "and the excluded ones are reported, not hidden")

p1 = r.players["0"]
t.eq(#p1.calls_per_frame, 1, "still ONE bucket - the gated frames did not invent a second")
t.eq(p1.calls_per_frame[1].calls, 1, "of exactly one call")

finding = CS.calls_per_frame_finding(r, 0)
t.ok(finding.conclusive, "the finding survives the round transition")
t.eq(finding.calls_per_frame, 1, "and still says one call per frame")

-- --- a genuine two-call build must still be caught --------------------------

t.group("a real second call is not suppressed")

s = CS.new()
for _ = 1, 400 do CS.add_frame(s, frame({ calls = { [0] = 2, [1] = 2 }, hitstop = true })) end
r = CS.report(s)
finding = CS.calls_per_frame_finding(r, 0)
t.ok(finding.conclusive, "a consistent two-call build is conclusive too")
t.eq(finding.calls_per_frame, 2, "and reports two")

-- Mixed counts are the honest "I do not know" case.
s = CS.new()
for _ = 1, 200 do CS.add_frame(s, frame({ hitstop = true })) end
for _ = 1, 200 do CS.add_frame(s, frame({ calls = { [0] = 2, [1] = 1 } })) end
r = CS.report(s)
finding = CS.calls_per_frame_finding(r, 0)
t.eq(finding.conclusive, false, "a varying call count is not conclusive")
t.ok(finding.reason:find("varies", 1, true) ~= nil, "and says the count varied")
t.eq(#finding.histogram, 2, "handing back the histogram so a human can look")

-- --- pause and partial frames ------------------------------------------------

t.group("pause and partial frames")

s = CS.new()
for _ = 1, 300 do CS.add_frame(s, frame({ hitstop = true })) end
for _ = 1, 50 do CS.add_frame(s, frame({ paused = true, calls = {} })) end
CS.add_frame(s, frame({ partial = true }))
r = CS.report(s)

t.eq(r.frames.excluded_paused, 50, "paused frames excluded and counted")
t.eq(r.frames.excluded_partial, 1, "the frame the probe started mid-way through is excluded")
t.eq(r.frames.included, 300, "only real frames remain")
t.eq(#r.players["0"].calls_per_frame, 1, "and the histogram stays clean")

-- The engine-frame counter must skip pauses the same way upstream's does,
-- otherwise the gap it reports is a pause, not a clock difference.
s = CS.new()
for _ = 1, 100 do CS.add_frame(s, frame({ hitstop = true })) end
for _ = 1, 100 do CS.add_engine_frame(s, false) end
for _ = 1, 250 do CS.add_engine_frame(s, true) end
r = CS.report(s)
t.eq(r.engine_frames.counted, 100, "paused render frames are not counted as engine frames")
t.eq(r.engine_frames.skipped_while_paused, 250, "they are reported separately")
t.eq(r.tick_vs_engine_gap, 0, "so a long pause does not masquerade as clock drift")

-- --- hitstop, which is the actual question -----------------------------------

t.group("hitstop is measured against the input-hook tick")

-- The clock under suspicion is the INPUT-HOOK tick, not the battle-frame one.
-- The battle sim carries on during hitstop; the characters are frozen. What
-- upstream describes as frames going "missing between engine ticks" is
-- pl_input_sub not firing - and a delay counted in input ticks stalls exactly
-- as much as those calls do.
--
-- Writing this test the wrong way first was instructive: simulating a stalled
-- BATTLE clock produced no observable hitstop frames at all, because there were
-- no frames on which to observe it.

local function hitstop_run(s, normal_frames, episodes, ep_len, calls_during)
    for _ = 1, normal_frames do
        CS.add_frame(s, frame({ hitstop = false, tick = 0 }))
        CS.add_engine_frame(s, false)
    end
    for _ = 1, episodes do
        for _ = 1, ep_len do
            CS.add_frame(s, frame({
                hitstop = true, hitstop_value = ep_len,
                calls = calls_during and { [0] = 1, [1] = 1 } or {},
            }))
            CS.add_engine_frame(s, false)
        end
        for _ = 1, 20 do
            CS.add_frame(s, frame({ hitstop = false }))
            CS.add_engine_frame(s, false)
        end
    end
end

-- The suspected case: the hook does not fire while frozen.
s = CS.new()
hitstop_run(s, 300, 4, 8, false)
r = CS.report(s)

t.eq(r.hitstop.episodes, 4, "four episodes recorded")
t.ok(r.hitstop.conclusive, "and they answer the question")
t.eq(r.hitstop.finding, "input_ticks_stall_during_hitstop", "the stall is detected")
t.eq(r.hitstop.calls_per_frame_in_hitstop, 0, "no calls during hitstop")
t.eq(r.hitstop.calls_per_frame_outside, 1, "one call per frame outside it")
t.ok(r.hitstop.reason:find("stall in hitstop", 1, true) ~= nil, "and it is stated in words")
t.eq(r.hitstop.detail[1].battle_frames, 8, "each episode carries its own length")

-- The other case: the hook keeps firing, so a delay in input ticks is a delay
-- in frames after all.
s = CS.new()
hitstop_run(s, 300, 4, 8, true)
r = CS.report(s)
t.eq(r.hitstop.finding, "input_ticks_advance_during_hitstop", "a hook that keeps firing says so")
t.ok(r.hitstop.conclusive, "which is equally a conclusion")

-- No hitstop at all is not a finding either way.
r = CS.report(sample(400))
t.eq(r.hitstop.episodes, 0, "no episodes")
t.eq(r.hitstop.conclusive, false, "so nothing is concluded")
t.ok(r.hitstop.reason:find("land some hits", 1, true) ~= nil, "and the operator is told what to do")

t.group("drift that cancels is still visible")

-- An endpoint subtraction misses a drift that accrues and then comes back, so
-- the worst instantaneous difference is kept alongside it.
s = CS.new()
for _ = 1, 100 do
    CS.add_frame(s, frame({ hitstop = true, hitstop_value = 1 }))
    CS.add_engine_frame(s, false)
end
for _ = 1, 30 do CS.add_engine_frame(s, false) end          -- engine runs ahead
for _ = 1, 30 do CS.add_frame(s, frame({ hitstop = false })) end  -- battle catches up
r = CS.report(s)
t.eq(r.tick_vs_engine_gap, 0, "the endpoint difference is zero")
t.ok(r.max_abs_drift >= 29, "but the worst instantaneous drift is recorded (" .. r.max_abs_drift .. ")")

-- --- the sample has to be fit ------------------------------------------------

t.group("fitness")

-- Too short.
r = CS.report(sample(50, { hitstop = true }))
t.eq(r.assessment.usable, false, "50 frames is not enough")
t.ok(r.assessment.problems[1]:find("usable frames", 1, true) ~= nil, "and says so")

-- Long enough, but no hits: says nothing about the case under suspicion.
r = CS.report(sample(400))
t.eq(r.assessment.usable, false, "a sample with no hitstop is not fit")
local joined = table.concat(r.assessment.problems, " ")
t.ok(joined:find("hitstop", 1, true) ~= nil, "because hitstop is the thing being tested for")

t.eq(CS.calls_per_frame_finding(r, 0).conclusive, false,
     "an unfit sample yields no finding even when the histogram is clean")

-- Mostly gated: technically enough frames, but most of the session was blind.
s = CS.new()
for _ = 1, 320 do CS.add_frame(s, frame({ hitstop = true })) end
for _ = 1, 400 do CS.add_frame(s, frame({ gate_open = false, calls = {} })) end
r = CS.report(s)
t.eq(r.assessment.usable, false, "a mostly-gated session is not fit")
t.ok(table.concat(r.assessment.problems, " "):find("gate was closed", 1, true) ~= nil,
     "and the reason names the gate")

-- --- unknown conditions are excluded, not assumed ----------------------------

t.group("unknown conditions")

s = CS.new()
CS.add_frame(s, { calls = { [0] = 1 } })   -- gate_open not stated
r = CS.report(s)
t.eq(r.frames.included, 0, "a frame with an unstated gate is not included")
t.eq(r.frames.excluded_gate_closed, 1, "it is excluded, not assumed open")

t.eq(CS.add_frame(CS.new(), "nonsense"), false, "a non-record is rejected")

-- --- no player data ----------------------------------------------------------

t.group("missing player")

r = CS.report(CS.new())
t.eq(CS.calls_per_frame_finding(r, 0).conclusive, false, "no data is not a conclusion")
t.ok(CS.calls_per_frame_finding(r, 7).reason:find("no samples", 1, true) ~= nil,
     "an unseen player says so plainly")

return t.finish()
