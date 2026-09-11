-- Unit tests for func/ComboExplorer/core/RunnerFsm.lua
--
-- The runner is the piece that decides what a trial MEANT, so the failures it
-- can have are the quiet ones. These tests defend four of them.
--
-- ATTRIBUTION. The combo counter is shared between the two moves. If an
-- increase that belonged to A is counted towards B, the row reads "link", the
-- file parses, the report looks healthy, and the dataset is wrong. The
-- program's boundaries say to the tick when B's input begins, and nothing
-- before that can have been caused by it - so an expected action id arriving
-- early is withheld from the verdict and kept as a finding.
--
-- THE MASK COMES FROM THE PROGRAM. The runner knows no button bits and must
-- never grow any: SequenceCompiler already refused to build the program at all
-- unless the button map had been measured, and a second place to spell a bit is
-- a second place for a whiff that reads as "these moves do not link".
--
-- FOUR OUTCOMES, NOT ONE FAILURE. No move at all, a blocked move, a whiffed
-- move and the WRONG move are four different facts and only two of them say
-- anything negative about the link.
--
-- AND WHAT IS NOT A VERDICT AT ALL. A reset that would not converge, a stage
-- the game refreshed underneath the trial, a tick budget that ran out: these
-- produce no record. Recording one as a rejection would turn missing
-- information into a negative answer, which is the thing that stops anybody
-- ever re-testing the pair.

local t = require("tests.lua.harness")
local RF = require("func/ComboExplorer/core/RunnerFsm")
local SF = require("func/ComboExplorer/core/StageControlFsm")
local SC = require("func/ComboExplorer/core/SequenceCompiler")
local IM = require("func/ComboExplorer/core/InputMask")
local LV = require("func/ComboExplorer/core/LinkVerdict")
local RC = require("func/ComboExplorer/core/ResultCollector")

local ST = RF.STATE

-- Stands in for a completed calibration. "verified" here is a statement about
-- the test, not an endorsement of the provisional bit table.
local VERIFIED = IM.profile({
    buttons = { L = 0x10, M = 0x80, H = 0x100, SP = 0x20, AUTO = 0x200,
                PARRY = 0x40, DI = 0x1000, THROW = 0x2000 },
    dir = { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 },
    mirror_when = "falsy",
    status = "verified",
})

local A_ID, B_ID, OTHER_ID = 600, 700, 999

local ROUTE = {
    id = "r-test",
    character = "zangief",
    control_scheme = "modern",
    steps = {
        { index = 1, action_id = A_ID, input_method = "manual",
          notation = "\229\188\177" },                   -- 弱
        { index = 2, action_id = B_ID, input_method = "manual",
          notation = "2 + \228\184\173" },               -- 2 + 中
    },
}

-- tail_ticks = 0, and not by habit: the observation window is the runner's, and
-- a program that brings its own tail is refused by begin(). See the block at
-- the end of this file.
local PROGRAM = SC.compile(ROUTE, { profile = VERIFIED, delay = 4,
                                    lead_ticks = 4, hold_ticks = 2, tail_ticks = 0 })

t.group("the program these tests are driven from")

t.ok(PROGRAM ~= nil, "a two-step program compiles under a verified profile")
t.eq(PROGRAM.total_ticks, 12, "and is 12 ticks: 4 lead, 2, 4 delay, 2, and no tail")
t.eq(PROGRAM.steps[1].input_starts_at_tick, 4, "move A's input begins after the lead")
t.eq(PROGRAM.steps[2].input_starts_at_tick, 10, "and move B's after the delay")
t.eq(PROGRAM.steps[2].input_ends_at_tick, 12, "ending two ticks later")

-- --- the mock adapter --------------------------------------------------------

local REMOVE = setmetatable({}, { __tostring = function() return "<removed>" end })

-- The reset the stage machine sees: the flag goes up on tick 2, is up for two
-- ticks, and everything is where it should be afterwards.
local function base(tick)
    return {
        refreshing = (tick >= 2 and tick <= 3),
        attacker_pos = -150, victim_pos = 150,
        attacker_act_st = 0, victim_act_st = 0,
        combo_count = 0, guard_count = 0,
    }
end

local function snap(tick, over)
    local s = base(tick)
    for k, v in pairs(over or {}) do
        if v == REMOVE then s[k] = nil else s[k] = v end
    end
    return s
end

local function stage_cfg(over)
    local c = {
        settle_ticks = 2,
        grace_ticks = 1,
        position_tolerance = 0.5,
        correction_retries = 3,
        refresh_timeout_ticks = 20,
        settle_timeout_ticks = 60,
        target_positions = { attacker = -150, victim = 150 },
        pin = false,
    }
    for k, v in pairs(over or {}) do
        if v == REMOVE then c[k] = nil else c[k] = v end
    end
    return c
end

-- With that stage configuration the reset finishes on tick 8, so program tick N
-- is driven tick 8 + N. Every script below is written in PROGRAM ticks, because
-- that is the clock the attribution rules are stated in.
local READY_AT = 8

local function runner_cfg(stage, over)
    local c = {
        stage = stage,
        observe_ticks = 5,
        trial_timeout_ticks = 200,
        grace_ticks = 2,
    }
    for k, v in pairs(over or {}) do
        if v == REMOVE then c[k] = nil else c[k] = v end
    end
    return c
end

local function trial_spec(over)
    local s = {
        program = PROGRAM,
        expected = { [1] = { A_ID }, [2] = { B_ID } },
        edge_id = "e:600->700",
        attempt = 1,
        provenance = { calibration_id = "cal-test", game_patch = "2026-08-03" },
    }
    for k, v in pairs(over or {}) do
        if v == REMOVE then s[k] = nil else s[k] = v end
    end
    return s
end

-- Drives one whole trial. `at(program_tick)` returns the overrides for that
-- tick; program tick 1 is the first injected tick, and anything at or below
-- zero is happening during the reset.
local function play(o)
    o = o or {}
    local stage = SF.new(stage_cfg(o.stage))
    local runner, why = RF.new(runner_cfg(stage, o.runner))
    if not runner then return nil, why end
    local ok, berr = runner:begin(trial_spec(o.spec))
    if not ok then return nil, berr end

    local cmds = {}
    for tick = 1, (o.ticks or 80) do
        local over = o.at and o.at(tick - READY_AT, tick) or nil
        cmds[#cmds + 1] = runner:tick(snap(tick, over))
        if cmds[#cmds].outcome ~= nil then break end
    end
    return runner, cmds
end

-- The ordinary trial: A commits a couple of ticks after its input and hits, B
-- commits after its own input and raises the counter. Written as a script over
-- program ticks so each test can bend one piece of it.
local function scripted(events)
    return function(pt)
        local over = {}
        for _, e in ipairs(events) do
            if pt >= e.from and (e.to == nil or pt <= e.to) then
                for k, v in pairs(e.set) do over[k] = v end
            end
        end
        return over
    end
end

local LINKED = scripted({
    { from = 6,  to = 12, set = { attacker_action_id = A_ID } },
    { from = 8,  to = 12, set = { combo_count = 1 } },
    { from = 13, set = { attacker_action_id = B_ID, combo_count = 2 } },
})

-- --- the timeouts are not guessed --------------------------------------------

t.group("a runner with an unset timeout refuses to start")

local stage_for_new = SF.new(stage_cfg())
local missing = 0
for _, req in ipairs(RF.REQUIRED) do
    local r, why = RF.new(runner_cfg(stage_for_new, { [req.key] = REMOVE }))
    if r ~= nil or type(why) ~= "string" or not why:find(req.key, 1, true) then
        missing = missing + 1
    end
end
t.eq(missing, 0, "every required tick budget refuses by name when unset")

t.is_nil(RF.new(runner_cfg(stage_for_new, { observe_ticks = -1 })),
         "a negative observation window is refused")
t.is_nil(RF.new(runner_cfg(nil, {})),
         "a runner with no stage machine to reset with is refused")
t.is_nil(RF.new(runner_cfg({ start = 1 }, {})),
         "and so is something that is not a stage machine")
t.is_nil(RF.new(nil), "no configuration at all is refused")

-- --- what will not be run ----------------------------------------------------

t.group("a trial that cannot mean anything is not started")

local preview = SC.compile(ROUTE, { profile = IM.profile({
    buttons = { L = 0x10, M = 0x80 },
    dir = { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 },
    status = "unverified",
}), delay = 4, allow_unverified = true })
t.eq(preview.profile_status, "unverified",
     "a read-only preview program exists to be refused")

local nope, nope_why = play({ spec = { program = preview } })
t.is_nil(nope, "a program compiled from an unmeasured button map is not injected")
t.ok(nope_why:find("unverified") ~= nil,
     "and the refusal names the profile: " .. tostring(nope_why))

t.is_nil(play({ spec = { program = REMOVE } }), "a trial with no program is refused")
t.is_nil(play({ spec = { expected = REMOVE } }),
         "a trial that does not say which action ids to expect is refused")
t.is_nil(play({ spec = { expected = { [1] = { A_ID } } } }),
         "expecting nothing of move B is refused, since B is the question")
t.is_nil(play({ spec = { expected = { [1] = { A_ID }, [2] = {} } } }),
         "and an empty list of ids for B is refused rather than read as none")
t.is_nil(play({ spec = { edge_id = REMOVE } }),
         "a trial that names neither an edge nor a route is refused")
t.is_nil(play({ spec = { attempt = REMOVE } }),
         "a trial that does not say which attempt it is is refused")
t.is_nil(play({ spec = { judge_gap = 4 } }),
         "asking about a gap the program does not have is refused")

-- A budget smaller than the program guarantees every trial times out, and a
-- sweep of timeouts looks exactly like a sweep of hardware trouble.
-- Derived from the program rather than written out, so it stays below the floor
-- when the program's length changes. It did: dropping the tail took the program
-- from 18 ticks to 12, and a hardcoded 20 quietly stopped being too small.
local tight, tight_why = play({
    runner = { trial_timeout_ticks = PROGRAM.total_ticks + 1 } })
t.is_nil(tight, "a tick budget that cannot cover the program is refused up front")
t.ok(tight_why:find("budget") ~= nil, "and says so: " .. tostring(tight_why))

local busy = RF.new(runner_cfg(SF.new(stage_cfg())))
t.ok(busy:begin(trial_spec()) == true, "a trial starts")
t.is_nil(busy:begin(trial_spec()), "and a second one cannot start on top of it")

-- --- the ordinary trial ------------------------------------------------------

t.group("the ordinary trial")

local runner, cmds = play({ at = LINKED })
t.ok(runner ~= nil, "the trial runs")

local seen = {}
for _, c in ipairs(cmds) do
    if seen[#seen] ~= c.state then seen[#seen + 1] = c.state end
end
t.eq_list(seen, { ST.RESETTING, ST.INJECTING, ST.OBSERVING, ST.JUDGING, ST.RECORDING },
          "through reset, injection, observation, judgement and recording, in that order")

local res = runner:result()
t.eq(res.outcome, "judged", "and ends with a verdict")
t.eq(res.verdict, LV.VERDICT.LINK, "which here is a link")
t.eq(res.produced_record, true, "a record was produced")
t.eq(res.retryable, false, "and there is nothing to re-queue")
t.eq(res.program_tick_reached, PROGRAM.total_ticks,
     "every tick of the program was played")
t.eq(res.observed_ticks, 5, "and the observation window was watched to the end")

-- --- the masks are the program's ---------------------------------------------

t.group("the runner plays the program and builds nothing")

local wrong_mask, injected = 0, 0
for _, c in ipairs(cmds) do
    if c.state == ST.INJECTING then
        injected = injected + 1
        if c.inject_mask ~= PROGRAM.raw_inputs[c.program_tick] then
            wrong_mask = wrong_mask + 1
        end
    end
end
t.eq(injected, PROGRAM.total_ticks, "one injecting tick per program tick")
t.eq(wrong_mask, 0, "each carrying exactly the mask the compiler put at that tick")

local stray = 0
for _, c in ipairs(cmds) do
    if c.state ~= ST.INJECTING and c.inject_mask ~= nil then stray = stray + 1 end
end
t.eq(stray, 0, "and no mask is written in any other state")

local during_reset = 0
for _, c in ipairs(cmds) do
    if c.state == ST.RESETTING and (c.inject_mask ~= nil or c.release ~= true) then
        during_reset = during_reset + 1
    end
end
t.eq(during_reset, 0,
     "nothing is injected while the stage is resetting, where an input is swallowed")

-- --- attribution -------------------------------------------------------------

t.group("an observation before a step's boundary is not that step's")

-- B's action id appears at program tick 9 - one tick BEFORE B's input begins -
-- and the counter goes up with it. That rise is A's second hit, whatever id was
-- showing: no input for B has happened yet. B's real appearance at tick 13
-- raises nothing.
local early, ecmds = play({ at = scripted({
    { from = 6,  to = 8,  set = { attacker_action_id = A_ID } },
    { from = 8,  set = { combo_count = 1 } },
    { from = 9,  to = 9,  set = { attacker_action_id = B_ID, combo_count = 2 } },
    { from = 10, to = 12, set = { attacker_action_id = A_ID, combo_count = 2 } },
    { from = 13, set = { attacker_action_id = B_ID, combo_count = 2 } },
}) })
local eres = early:result()
t.eq(eres.verdict, LV.VERDICT.WHIFF,
     "a counter rise before B's input belongs to A, so B is judged to have hit nothing")
t.ok(eres.verdict ~= LV.VERDICT.LINK,
     "attributing it to B would have called this a link, which is the bug this defends")

t.eq(#eres.withheld_action_ids, 1, "the early sighting is recorded, not dropped")
t.eq(eres.withheld_action_ids[1].tick, 9, "with the tick it happened on")
t.eq(eres.withheld_action_ids[1].action_id, B_ID, "and the id that was seen")
t.eq(eres.withheld_action_ids[1].attributable_from_tick, 10,
     "and the tick from which it would have counted")

local ev = eres.record.evidence
t.eq(ev.b_first_tick, 13,
     "B is first believed on the tick its own action really appeared")
t.eq(ev.combo_before_b, 2, "so the counter B is measured against includes A's second hit")
t.eq(ev.hits_added, 0, "and B added nothing")

-- The boundary itself, to the tick. B's input begins after tick 10, so an id at
-- exactly tick 10 is still too early and one at tick 11 is not.
local edge = play({ at = scripted({
    { from = 6, to = 9, set = { attacker_action_id = A_ID } },
    { from = 8, set = { combo_count = 1 } },
    { from = 10, set = { attacker_action_id = B_ID } },
    { from = 14, set = { combo_count = 2 } },
}) })
local dres = edge:result()
t.eq(#dres.withheld_action_ids, 1, "the tick equal to the boundary is withheld")
t.eq(dres.withheld_action_ids[1].tick, 10,
     "because the input for that tick had not been written yet")
t.eq(dres.record.evidence.b_first_tick, 11,
     "and the very next tick is the first that may be attributed to B")
t.eq(dres.verdict, LV.VERDICT.LINK, "a rise after that boundary is B's, and is a link")

-- --- four outcomes, not one failure ------------------------------------------

t.group("a trial has more than two possible answers")

local function verdict_of(at)
    local r = play({ at = at })
    return r:result()
end

local none = verdict_of(scripted({}))
t.eq(none.verdict, LV.VERDICT.A_FAILED,
     "a trial where no move came out at all is not a failed link")
t.ok(none.record.evidence.reason:find("never came out") ~= nil,
     "and says move A never appeared: " .. tostring(none.record.evidence.reason))

local blocked = verdict_of(scripted({
    { from = 6,  to = 12, set = { attacker_action_id = A_ID } },
    { from = 8,  set = { combo_count = 1 } },
    { from = 13, set = { attacker_action_id = B_ID } },
    { from = 15, set = { guard_count = 1 } },
}))
t.eq(blocked.verdict, LV.VERDICT.BLOCKED,
     "a move the dummy guarded is blocked, not whiffed")

local whiffed = verdict_of(scripted({
    { from = 6,  to = 12, set = { attacker_action_id = A_ID } },
    { from = 8,  set = { combo_count = 1 } },
    { from = 13, set = { attacker_action_id = B_ID } },
}))
t.eq(whiffed.verdict, LV.VERDICT.WHIFF,
     "a move that came out and touched nothing whiffed")

local wrong = verdict_of(scripted({
    { from = 6,  to = 12, set = { attacker_action_id = A_ID } },
    { from = 8,  set = { combo_count = 1 } },
    { from = 13, set = { attacker_action_id = OTHER_ID } },
}))
t.eq(wrong.verdict, LV.VERDICT.WRONG_MOVE,
     "and a different move entirely is a wrong move")
t.eq(wrong.record.evidence.unexpected_action_ids[1], OTHER_ID,
     "with the id that came out instead recorded, because that is itself a finding")

local answers = {}
for _, r in ipairs({ none, blocked, whiffed, wrong }) do answers[r.verdict] = true end
local distinct = 0
for _ in pairs(answers) do distinct = distinct + 1 end
t.eq(distinct, 4, "four scenarios, four different answers")

-- --- what produces no record -------------------------------------------------

t.group("a trial the game interrupted is not a result")

-- The game raises _IsReqRefresh on its own, mid-trial.
local mid = play({ at = function(pt)
    if pt >= 5 then return { refreshing = true } end
    return nil
end })
local mres = mid:result()
t.eq(mres.outcome, "abandoned", "a stage reset underneath the trial abandons it")
t.eq(mres.stopped_in, ST.INJECTING, "naming the state it was interrupted in")
t.is_nil(mres.verdict, "no verdict is reached")
t.eq(mres.produced_record, false, "and nothing at all is recorded about the pair")
t.eq(mres.retryable, true, "the trial is re-queued instead")

local mid_runner, mid_cmds = play({ at = function(pt)
    if pt >= 5 then return { refreshing = true } end
    return nil
end })
t.eq(mid_cmds[#mid_cmds].outcome, "abandoned",
     "the last command is the one that abandons")
t.is_nil(mid_cmds[#mid_cmds].inject_mask, "and it writes no input")
t.is_nil(mid_runner:tick(snap(99)).inject_mask,
         "nor does any tick after it, however long the caller keeps ticking")

-- A reset that never converges. The refresh flag is never seen to rise, so
-- whether the stage was reset at all is unknown.
local unreset = play({ at = function(_, tick)
    return { refreshing = false }
end })
local ures = unreset:result()
t.eq(ures.outcome, "reset_failed",
     "a stage that never became reproducible fails the trial")
t.eq(ures.produced_record, false, "with no record written")
t.eq(ures.retryable, true, "and the trial left to be re-queued")
t.eq(ures.stopped_in, ST.RESETTING, "having got no further than the reset")

-- A budget that runs out. The stage is configured to allow a long settle, the
-- runner is not, and the runner's own budget is what reports.
local slow = play({
    runner = { trial_timeout_ticks = 25 },
    at = function(_, tick)
        if tick >= 4 then return { combo_count = 3 } end
        return nil
    end,
})
local sres = slow:result()
t.eq(sres.outcome, "timeout", "a trial that outlives its budget reports a timeout")
t.eq(sres.ticks, 26, "on the tick after the budget was spent")
t.eq(sres.produced_record, false, "and records nothing about the pair")
t.ok(sres.reason:find("budget") ~= nil, "saying what ran out: " .. tostring(sres.reason))

-- --- the injection gate ------------------------------------------------------

t.group("a hole in the program is not a trial")

local gated = play({ at = function(pt)
    if pt == 5 then return { can_inject = false } end
    return nil
end })
local gres = gated:result()
t.eq(gres.outcome, "abandoned", "a shut injection gate abandons the trial")
t.ok(gres.reason:find("gate") ~= nil,
     "rather than playing the program with a tick missing: " .. tostring(gres.reason))
t.eq(gres.produced_record, false, "and no verdict is recorded from a program half played")

-- Unknown is not known-shut. The same tick that abandoned the trial above is
-- left unreadable here instead of shut: GameAdapter.can_inject returns nil when
-- RuntimeSafety cannot be asked, and refusing on that would stop every trial on
-- a machine that simply does not publish the gate.
local unknown = play({ at = function(pt, tick)
    local over = LINKED(pt, tick)
    if pt == 5 then over.can_inject = nil else over.can_inject = true end
    return over
end })
t.eq(unknown:result().outcome, "judged",
     "a gate that could not be read is not a gate that said no")
t.eq(unknown:result().verdict, LV.VERDICT.LINK, "and the trial answers its question")

-- --- the record --------------------------------------------------------------

t.group("what the runner hands to the collector")

local rec = runner:result().record
t.ok(rec ~= nil, "a judged trial produces a record spec")
t.eq(rec.edge_id, "e:600->700", "naming the subject it was about")
t.eq_list(rec.delays, { 4 }, "at the delay the program was compiled for")
t.eq(rec.attempt, 1, "and which attempt it was")
t.eq(rec.verdict, LV.VERDICT.LINK, "carrying the verdict")
t.eq(rec.character, "zangief", "the character it ran as")
t.eq(rec.control_scheme, "modern", "and the control scheme")
t.eq(rec.evidence.judge_gap, 1, "the evidence says which gap was judged")
t.eq(rec.evidence.stage.outcome, "ready", "and carries the reset it ran after")
t.ok(rec.evidence.stage.ticks_to_ready > 0, "including how long that reset took")
t.eq(rec.program, PROGRAM,
     "the program is handed over whole, for the collector to digest")

-- The contract, not a re-implementation of it: the spec has to be something
-- ResultCollector will actually accept, or the trial is lost at the file.
local written, problems = RC.trial(rec)
t.ok(written ~= nil, "and ResultCollector accepts it as a trial record")
if written == nil then
    t.fail("problems: " .. tostring(problems and problems[1] and problems[1].problem))
else
    t.eq(written.status, "verified", "a link is a verified edge")
    t.eq(written.runtime_verified, true, "and carries its runtime evidence")
end

local wrong_rec = RC.trial(wrong.record)
t.ok(wrong_rec ~= nil, "a wrong-move trial is also a record")
t.eq(wrong_rec.status, "runtime_pending",
     "but is pending rather than rejected: the wrong move says nothing about the link")

-- --- degenerate input --------------------------------------------------------

t.group("degenerate input")

local idle = RF.new(runner_cfg(SF.new(stage_cfg())))
local icmd = idle:tick(snap(1))
t.eq(icmd.state, ST.IDLE, "a runner with no trial in flight stays idle")
t.is_nil(icmd.inject_mask, "and writes nothing")

-- A snapshot that could not be read at all is not an observation, and a run of
-- them is not a trial that answered no.
local half = RF.new(runner_cfg(SF.new(stage_cfg())))
half:begin(trial_spec())
for _ = 1, 12 do half:tick(nil) end
local hres = half:result()
t.is_nil(hres.outcome, "ticking with no snapshot at all reaches no conclusion")
t.eq(hres.state, ST.RESETTING, "and the trial is still waiting for a stage it can read")

-- --- one window, and it belongs to this machine ------------------------------

t.group("a program that brings its own observation window is refused")

-- The tail used to default to 30. The runner watched the program's ticks,
-- including those 30, and then observed for `observe_ticks` MORE - while the
-- evidence row recorded `observe_ticks` alone. The number a reader would use to
-- say "we watched long enough" was smaller than the window that actually ran,
-- and the 30 itself was an unmeasured constant that was never in Provenance.

do
    local preview = SC.compile(ROUTE, { profile = VERIFIED, delay = 4,
                                        lead_ticks = 4, hold_ticks = 2, tail_ticks = 6 })
    t.eq(preview.total_ticks, 18, "a preview build still gets its tail")
    t.eq(preview.tail_ticks, 6, "and says how long it is")

    local f = RF.new(runner_cfg(SF.new(stage_cfg())))
    local ok, why = f:begin(trial_spec({ program = preview }))
    t.is_nil(ok, "and the runner will not run it")
    t.ok(tostring(why):find("tail ticks of its own") ~= nil,
         "saying which window it objects to: " .. tostring(why))
    t.ok(tostring(why):find("tail_ticks = 0") ~= nil, "and how to fix it")
end

do
    t.eq(PROGRAM.tail_ticks, 0, "the trial program has no tail of its own")
    local f = RF.new(runner_cfg(SF.new(stage_cfg())))
    t.ok(f:begin(trial_spec()) == true, "so it starts")
end

do
    -- Silence is not a tail. A program from an older build carries no such
    -- field, and refusing it would be reading "nobody said" as bad news.
    local quiet = {}
    for k, v in pairs(PROGRAM) do quiet[k] = v end
    quiet.tail_ticks = nil
    local f = RF.new(runner_cfg(SF.new(stage_cfg())))
    t.ok(f:begin(trial_spec({ program = quiet })) == true,
         "a program that does not mention a tail is not refused for having one")
end

return t.finish()
