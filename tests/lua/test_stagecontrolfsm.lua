-- Unit tests for func/ComboExplorer/core/StageControlFsm.lua
--
-- What these defend is the difference between a stage that has been reset and a
-- stage that has been ASKED to reset. The request is asynchronous, the position
-- write does not land first time, the resources are servoed back every frame,
-- and the combo counter goes on reading the previous trial for a while after
-- the flag clears. Every one of those makes "reset, then inject on the next
-- frame" produce a trial that runs against a stage in motion and records
-- whatever it happens to see.
--
-- The refusals are the point, so they are tested harder than the happy path:
--
--   * The tick counts are unmeasured, so an unset one has to refuse rather than
--     default. Provenance.value() hands out nil until a real calibration says
--     otherwise, and that nil has to reach a refusal, not a fallback.
--   * WAIT_REFRESH must never allow an input. An input during a refresh is
--     swallowed, the move never comes out, and the pair is recorded as "these
--     moves do not link" - a confident negative with no error anywhere.
--   * A flag that reads false one tick after the request is the engine not
--     having looked yet, and a flag that cannot be read at all is not a flag
--     that says no.
--   * A refresh the game raises on its own ABANDONS the trial. Abandoned and
--     failed have to stay distinguishable, because only one of them is a
--     statement about the reset.

local t = require("tests.lua.harness")
local SF = require("func/ComboExplorer/core/StageControlFsm")
local Provenance = require("func/ComboExplorer/core/Provenance")

local S = SF.STATE

-- Removing a key has to be expressible, because "unset" is the case under test.
local REMOVE = setmetatable({}, { __tostring = function() return "<removed>" end })

local function cfg(over)
    local c = {
        settle_ticks = 4,
        grace_ticks = 3,
        position_tolerance = 0.5,
        correction_retries = 3,
        refresh_timeout_ticks = 20,
        settle_timeout_ticks = 60,
        target_positions = { attacker = -150, victim = 150 },
        pin = { attacker_hp = 10000, victim_hp = 10000 },
    }
    for k, v in pairs(over or {}) do
        if v == REMOVE then c[k] = nil else c[k] = v end
    end
    return c
end

-- The mock adapter: a snapshot is whatever the game would have said this tick,
-- and the test says it instead.
local function snap(over)
    local s = {
        refreshing = false,
        attacker_pos = -150, victim_pos = 150,
        attacker_act_st = 0, victim_act_st = 0,
        combo_count = 0, guard_count = 0,
        attacker_hp = 10000, victim_hp = 10000,
    }
    for k, v in pairs(over or {}) do
        if v == REMOVE then s[k] = nil else s[k] = v end
    end
    return s
end

-- A scripted list of snapshots, one per tick: script(n, f) asks f for the
-- overrides at tick i.
local function script(n, f)
    local out = {}
    for i = 1, n do out[i] = snap(f and f(i) or nil) end
    return out
end

local function drive(fsm, snaps)
    local cmds = {}
    for i, s in ipairs(snaps) do cmds[i] = fsm:tick(s) end
    return cmds
end

local function first_state(cmds, state)
    for i, c in ipairs(cmds) do
        if c.state == state then return i, c end
    end
end

local function count_state(cmds, state)
    local n = 0
    for _, c in ipairs(cmds) do if c.state == state then n = n + 1 end end
    return n
end

-- The ordinary reset used by most of the tests below: one tick of REQUEST,
-- three ticks with the flag high, then it clears and everything is where it
-- should be.
local function ordinary(n)
    return script(n or 40, function(i)
        if i >= 2 and i <= 4 then return { refreshing = true } end
        return nil
    end)
end

-- --- the tick counts are not defaulted ---------------------------------------

t.group("a reset with an unmeasured tick count refuses to start")

local missing = 0
for _, req in ipairs(SF.REQUIRED) do
    local fsm, why = SF.new(cfg({ [req.key] = REMOVE }))
    if fsm ~= nil or type(why) ~= "string" or not why:find(req.key, 1, true) then
        missing = missing + 1
    end
end
t.eq(missing, 0,
     "every required tick count, tolerance and target refuses by name when unset")

local _, all_why = SF.new({})
local named = 0
for _, req in ipairs(SF.REQUIRED) do
    if all_why:find(req.key, 1, true) then named = named + 1 end
end
t.eq(named, #SF.REQUIRED,
     "an empty configuration is refused with every missing value named at once")

t.is_nil(SF.new(cfg({ settle_ticks = -1 })), "a negative settle count is refused")
t.is_nil(SF.new(cfg({ settle_ticks = 2.5 })), "a fractional tick count is refused")
t.is_nil(SF.new(cfg({ position_tolerance = -0.1 })), "a negative tolerance is refused")
t.is_nil(SF.new(cfg({ target_positions = true })),
         "a target that is not a pair of positions is refused")
t.is_nil(SF.new(cfg({ pin = "everything" })),
         "a pin that is not a table of targets is refused")
t.is_nil(SF.new(nil), "no configuration at all is refused")

-- false and nil are different facts, and this module depends on the difference.
t.ok(SF.new(cfg({ target_positions = false })) ~= nil,
     "false says the caller knowingly corrects no position, and is accepted")
t.ok(SF.new(cfg({ pin = false })) ~= nil,
     "false says the caller knowingly pins nothing, and is accepted")
t.is_nil(SF.new(cfg({ pin = REMOVE })),
         "nil says nobody decided, and is refused")

-- --- the value really does arrive from Provenance ----------------------------

t.group("the settle count comes from the register, which withholds it")

local reg = Provenance.new()
local unverified = Provenance.value(reg, "reset_settle_ticks")
t.is_nil(unverified, "reset_settle_ticks is withheld while it is unverified")

-- Exactly what a caller does: assign the register's answer into the config.
-- The answer is nil, so the key is simply not there.
local wired = cfg()
wired.settle_ticks = Provenance.value(reg, "reset_settle_ticks")
local refused, refused_why = SF.new(wired)
t.is_nil(refused, "so a caller wiring the register straight in gets a refusal")
t.ok(refused_why:find("settle_ticks", 1, true) ~= nil,
     "and the refusal names the value that is missing")

local provisional, status = Provenance.provisional(reg, "reset_settle_ticks")
t.eq(provisional, 25, "the guess exists, and it is 25")
t.eq(status, "unverified", "but it is only ever handed over with its status attached")

Provenance.apply_calibration(reg, {
    calibration_id = "test", game_patch = "p",
    values = { reset_settle_ticks = { status = "verified", value = 8 } },
})
wired.settle_ticks = Provenance.value(reg, "reset_settle_ticks")
t.eq(wired.settle_ticks, 8,
     "once a calibration has measured it, the register hands it over")
t.ok(SF.new(wired) ~= nil, "and only then does the reset machine agree to run")

-- --- the ordinary reset ------------------------------------------------------

t.group("the ordinary reset")

local fsm = SF.new(cfg())
fsm:start()
local cmds = drive(fsm, ordinary())

t.eq(cmds[1].state, S.REQUEST, "the first tick asks for the reset")
t.eq(cmds[1].request_refresh, true, "by raising the refresh request")
t.eq(cmds[2].state, S.WAIT_REFRESH, "and then it waits")
t.eq(cmds[5].refresh_cleared, true,
     "the tick the flag clears is the tick correction can start")
t.eq(cmds[6].state, S.CORRECT, "correction follows the refresh, not the request")
t.eq(cmds[7].state, S.PIN, "then the resources are pinned")
t.eq(cmds[8].state, S.SETTLE, "and only then does settling begin")

-- The arithmetic is spelled out because it is the whole claim: one request
-- tick, three ticks of flag, one clearing tick, one correct, one pin, then the
-- grace has to pass before four consecutive good ticks can even start counting.
local ready_at = first_state(cmds, S.READY)
t.eq(ready_at, 12,
     "READY lands on tick 12: request, refresh, correct, pin, grace, then four")
t.eq(cmds[12].outcome, "ready", "and the command says the reset finished")

local r = fsm:result()
t.eq(r.outcome, "ready", "the result reports the reset as ready")
t.eq(r.ticks_to_ready, 12,
     "and records how many ticks it took, so a slow reset is visible")
t.eq(r.settle_ticks_taken, 5, "including the ticks spent settling, grace included")
t.eq(r.refresh_ticks, 3, "and how long the refresh flag was actually up")
t.eq(r.corrected, true, "the position correction is reported as having landed")
t.eq(r.pinned, true, "and the pin as having held")
t.eq(r.unresolved_ticks, 0, "with nothing unreadable in this run")

-- --- nothing is injected before READY ----------------------------------------

t.group("no input escapes before the stage is ready")

local early = 0
for i, c in ipairs(cmds) do
    if c.inject_allowed == true and i < ready_at then early = early + 1 end
end
t.eq(early, 0, "no command before READY allows an input to be written")

local during_refresh = 0
for _, c in ipairs(cmds) do
    if c.state == S.WAIT_REFRESH and c.inject_allowed ~= false then
        during_refresh = during_refresh + 1
    end
end
t.eq(during_refresh, 0,
     "and WAIT_REFRESH in particular allows none: an input during a refresh is swallowed")

local ready_forbids = 0
for i = ready_at, #cmds do
    if cmds[i].inject_allowed ~= true then ready_forbids = ready_forbids + 1 end
end
t.eq(ready_forbids, 0, "from READY onwards every command allows it")

-- The resources are re-injected for as long as the machine runs, because the
-- engine servos them back every frame.
local unpinned = 0
for i = 7, #cmds do
    if cmds[i].pin_resources == nil then unpinned = unpinned + 1 end
end
t.eq(unpinned, 0, "and every tick from PIN onwards re-writes the pinned resources")

-- --- the refresh flag --------------------------------------------------------

t.group("the refresh flag is a request, not an answer")

-- The flag reads false on the tick after the request because the engine has not
-- looked yet. Believing that would start the trial into a stage about to be
-- torn down.
local never = SF.new(cfg())
never:start()
local ncmds = drive(never, script(30))
local nres = never:result()
t.eq(nres.outcome, "failed", "a refresh that is never observed high is a failed reset")
t.eq(nres.refresh_observed, false, "and the result says the flag was never seen up")
t.ok(nres.reason:find("never observed") ~= nil,
     "the reason says the reset may not have happened at all: " .. tostring(nres.reason))
t.eq(count_state(ncmds, S.CORRECT), 0, "correction never started on a stage nobody reset")
t.eq(count_state(ncmds, S.READY), 0, "and the stage never became ready")

-- An unreadable flag is not a flag that says "cleared".
local blind = SF.new(cfg())
blind:start()
local bcmds = drive(blind, script(30, function(i)
    if i == 2 then return { refreshing = true } end
    return { refreshing = REMOVE }
end))
t.eq(count_state(bcmds, S.CORRECT), 0,
     "a refresh flag that cannot be read is never taken for one that has cleared")
local bres = blind:result()
t.eq(bres.outcome, "failed", "the reset fails instead")
t.ok(bres.unresolved_ticks > 0, "and says how many ticks could not be read")

-- --- the write-time readback (issue #40) --------------------------------------

t.group("the rising edge of OUR OWN request is only visible at write time")

-- What build 24176760 actually does. The engine's training update runs between
-- two of our on_frame ticks, so a request raised at the end of tick N is
-- already consumed by the time tick N+1 polls: `refreshing` reads false on
-- EVERY tick of this script, exactly as the hardware reported
-- (refresh_observed false, refresh_wait_ticks 601, on a stage that had
-- demonstrably been reset). The readback the runtime took inside the same call
-- as the write arrives on tick 2 and is the rising edge.
local function acked(n, ack, over)
    return script(n or 40, function(i)
        local s = {}
        for k, v in pairs(over and over(i) or {}) do s[k] = v end
        if i == 2 then s.refresh_ack = ack end
        return s
    end)
end

local seen = SF.new(cfg())
seen:start()
local seen_cmds = drive(seen, acked(40, { before = false, after = true }))
local seen_res = seen:result()

t.eq(seen_res.outcome, "ready",
     "a request that read back high is a reset that started, even though the "
     .. "flag never once polled high: " .. tostring(seen_res.reason))
t.eq(seen_res.refresh_observed, true, "the rising edge counts as observed")
t.eq(seen_res.refresh_high_source, "write_readback",
     "and the result says WHERE it was observed, because a readback and a poll "
     .. "are not the same claim")
t.is_nil(seen_res.caveats,
     "with nothing unobserved: the write's own readback attributes the refresh "
     .. "to this request")
-- The arithmetic, spelled out: tick 1 requests, tick 2 reads the ack back high
-- AND reads the flag already low (the falling edge, same tick), 3 corrects,
-- 4 pins, 5 is inside the grace, then four consecutive good ticks.
t.eq(first_state(seen_cmds, S.READY), 9,
     "READY lands on tick 9 - three ticks sooner than the polled path, which is "
     .. "exactly the flag-high phase that is not observable for our requests")
t.eq(seen_cmds[2].refresh_cleared, true,
     "the falling edge is the very next thing after the readback, because the "
     .. "engine consumed the request between the two ticks")

-- The negative that matters most: the write did not land. Nothing of the engine
-- runs between the write and the readback, so a flag that is low there was
-- never raised - and that must NOT be rescued by the stage happening to look
-- perfect, which it does on every tick of this script.
local nowrite = SF.new(cfg())
nowrite:start()
local nw_cmds = drive(nowrite, acked(40, { before = false, after = false }))
local nw_res = nowrite:result()

t.eq(nw_res.outcome, "failed",
     "a request that read back false is a reset that never started")
t.eq(nw_res.refresh_observed, false, "with no rising edge anywhere")
t.ok(nw_res.reason:find("never landed") ~= nil,
     "and the reason says the request never landed rather than blaming a "
     .. "timeout: " .. tostring(nw_res.reason))
t.eq(nw_cmds[2].state, S.FAILED,
     "reported on tick 2, not after the 20-tick budget: waiting proves nothing "
     .. "once the write is known not to have landed")
t.eq(count_state(nw_cmds, S.READY), 0, "and the stage never becomes ready")

-- The same script, and the stage is sitting EXACTLY at its default positions,
-- idle, with no combo running, from the first tick to the last. Judging the
-- reset by its effect would call this a completed reset. It is a reset that
-- never happened.
local default_error = 0
for _, c in ipairs(nw_cmds) do
    if c.outcome == "ready" then default_error = default_error + 1 end
end
t.eq(default_error, 0,
     "a stage already at its defaults is never mistaken for a stage that was "
     .. "just reset to them")

-- A readback that could not be READ is not a readback that said no. It falls
-- back to the poll, and if that finds nothing either the reset fails saying
-- which evidence was missing - "nobody found out" stays distinct from "it did
-- not happen".
local blind_ack = SF.new(cfg())
blind_ack:start()
drive(blind_ack, acked(40, { before = nil, after = nil, error = "no training manager" }))
local ba_res = blind_ack:result()
t.eq(ba_res.outcome, "failed", "an unreadable readback with no polled rise fails")
t.ok(ba_res.reason:find("could not be read") ~= nil,
     "naming the readback as the evidence that was missing: " .. tostring(ba_res.reason))
t.ok(ba_res.reason:find("unknown") ~= nil,
     "and saying the answer is unknown rather than no")
t.eq(ba_res.refresh_ack.error, "no training manager",
     "with the adapter's own reason carried into the result")

-- The runtime never got as far as writing - no training manager, or the write
-- threw. Waiting out the budget would bury the adapter's own reason under a
-- timeout that says nothing.
local unwritten = SF.new(cfg())
unwritten:start()
local uw_cmds = drive(unwritten, acked(40, {
    wrote = false, before = nil, after = nil,
    error = "the training manager did not resolve",
}))
local uw_res = unwritten:result()
t.eq(uw_res.outcome, "failed", "a request that was never written fails at once")
t.eq(uw_cmds[2].state, S.FAILED, "on tick 2")
t.ok(uw_res.reason:find("never written") ~= nil,
     "saying so rather than timing out: " .. tostring(uw_res.reason))
t.ok(uw_res.reason:find("training manager") ~= nil,
     "and carrying the runtime's own reason, so the fix is visible")

-- Nobody wired a readback up at all. This is the pre-#40 behaviour, kept
-- deliberately so an adapter that does not report one is no worse than before -
-- but the failure now says that is what happened, instead of leaving the reader
-- to conclude the game ignored the request.
local no_ack = SF.new(cfg())
no_ack:start()
drive(no_ack, script(40))
local na_res = no_ack:result()
t.eq(na_res.outcome, "failed", "no readback and no polled rise is still a failure")
t.is_nil(na_res.refresh_ack, "with no readback recorded")
t.ok(na_res.reason:find("no write%-time readback") ~= nil,
     "and the reason names the missing wiring: " .. tostring(na_res.reason))

t.group("a refresh that cannot be attributed to us is reported, not assumed")

-- The flag polls high, but we have no readback of our own write. That rise may
-- be the operator's RESET ONCE - Probe C caught eleven of those - and there is
-- nothing here tying it to this request. The reset finishes; the result says
-- what was not observed.
local polled = SF.new(cfg())
polled:start()
drive(polled, ordinary())
local pol_res = polled:result()
t.eq(pol_res.outcome, "ready", "a polled refresh still completes the reset")
t.eq(pol_res.refresh_high_source, "poll", "by the polled route")
t.ok(pol_res.caveats ~= nil and pol_res.caveats[1]:find("attributed") ~= nil,
     "carrying a caveat that it cannot be attributed to this request: "
     .. tostring(pol_res.caveats and pol_res.caveats[1]))

-- The flag was ALREADY high when we asked. Raising a raised flag is a no-op, so
-- our request was coalesced into somebody else's refresh - which may have read
-- the training menu before write_setup touched it. The stage is still being
-- refreshed, so this is not a failure; it is a ready with something missing.
local overlapped = SF.new(cfg())
overlapped:start()
drive(overlapped, acked(40, { before = true, after = true }))
local ov_res = overlapped:result()
t.eq(ov_res.outcome, "ready", "a coalesced request still ends in a reset stage")
t.eq(ov_res.refresh_overlapped, true, "and records that it was coalesced")
t.ok(ov_res.caveats ~= nil and ov_res.caveats[1]:find("already high") ~= nil,
     "with the caveat naming what that costs: " .. tostring(ov_res.caveats and ov_res.caveats[1]))

t.group("the readback belongs to one frame")

-- It is evidence about the tick the request was written on. An ack arriving
-- three ticks later is a different frame's evidence and must not be believed,
-- or a stale latch becomes a reset nobody performed.
local stale = SF.new(cfg())
stale:start()
drive(stale, script(40, function(i)
    if i == 6 then return { refresh_ack = { before = false, after = true } } end
    return nil
end))
local st_res = stale:result()
t.eq(st_res.outcome, "failed",
     "a readback that arrives on a later tick is not this request's readback")
t.eq(st_res.refresh_observed, false, "so no rising edge was ever observed")

-- --- correction --------------------------------------------------------------

t.group("position correction retries, and reports not converging")

-- Off by four units for the first three correction ticks and in tolerance
-- afterwards: the write does not land first time, which is the case upstream
-- retries for.
local slow = SF.new(cfg())
slow:start()
local scmds = drive(slow, script(40, function(i)
    if i >= 2 and i <= 4 then return { refreshing = true } end
    if i < 9 then return { attacker_pos = -146 } end
    return nil
end))
local sres = slow:result()
t.eq(sres.outcome, "ready", "a correction that lands late still reaches ready")
t.ok(sres.correction_attempts > 1, "having taken more than one write to get there")
t.ok(first_state(scmds, S.READY) > ready_at,
     "and the reset is visibly slower than one that landed first time")

local stuck = SF.new(cfg())
stuck:start()
drive(stuck, script(40, function(i)
    if i >= 2 and i <= 4 then return { refreshing = true } end
    return { attacker_pos = -100 }
end))
local kres = stuck:result()
t.eq(kres.outcome, "failed", "a correction that never converges fails the reset")
t.eq(kres.correction_attempts, 3, "after exactly the retry budget it was given")
t.ok(kres.reason:find("converge") ~= nil,
     "and says it did not converge rather than proceeding: " .. tostring(kres.reason))
t.eq(kres.corrected, false, "the result records that the position was not corrected")
t.ok(kres.position_error > 0.5, "with the residual error attached")

-- A position that cannot be read has tested nothing, so it must not spend a
-- retry: doing so reports a correction as failed that was never attempted.
local unreadable = SF.new(cfg())
unreadable:start()
drive(unreadable, script(20, function(i)
    if i >= 2 and i <= 4 then return { refreshing = true } end
    return { attacker_pos = REMOVE, victim_pos = REMOVE }
end))
t.eq(unreadable:result().correction_attempts, 0,
     "an unreadable position spends no part of the retry budget")
t.eq(unreadable:result().outcome, nil,
     "and the reset is still in progress rather than declared failed")

-- --- settling ----------------------------------------------------------------

t.group("settling holds for N consecutive ticks, not one")

-- One good tick in the middle of a bad run must not be enough.
local flaky = SF.new(cfg())
flaky:start()
local fcmds = drive(flaky, script(40, function(i)
    if i >= 2 and i <= 4 then return { refreshing = true } end
    -- Ticks 9, 11 and 13 are busy, so the last break is at 13 and the first run
    -- of four good ticks can only be 14, 15, 16, 17.
    if i >= 9 and i <= 14 and (i % 2 == 1) then return { attacker_act_st = 12 } end
    return nil
end))
local flaky_ready = first_state(fcmds, S.READY)
t.eq(flaky_ready, 17, "the run restarts from zero every time a condition breaks")
t.ok(flaky_ready > ready_at,
     "so a stage that keeps twitching takes longer to be believed")

-- A snapshot that could not be read is not a settled snapshot either.
local dark = SF.new(cfg())
dark:start()
drive(dark, script(40, function(i)
    if i >= 2 and i <= 4 then return { refreshing = true } end
    return { combo_count = REMOVE }
end))
local dres = dark:result()
t.is_nil(dres.outcome, "an unreadable combo counter never settles the stage")
t.ok(dres.unresolved_ticks > 0, "and every such tick is counted")

-- The grace exists because the counter reads the previous trial for a while.
-- Widening it has to delay readiness by exactly that much.
local patient = SF.new(cfg({ grace_ticks = 10 }))
patient:start()
local pcmds = drive(patient, ordinary())
t.eq(first_state(pcmds, S.READY), ready_at + 7,
     "seven more ticks of grace is seven more ticks before the stage is believed")

local slowest = SF.new(cfg({ settle_timeout_ticks = 12 }))
slowest:start()
drive(slowest, script(40, function(i)
    if i >= 2 and i <= 4 then return { refreshing = true } end
    return { combo_count = 3 }
end))
local tres = slowest:result()
t.eq(tres.outcome, "failed",
     "a stage that never settles is reported, not waited on for ever")
t.ok(tres.reason:find("reproducible") ~= nil, "as a stage that never became reproducible")
t.ok(tres.settle_ticks_taken > 0, "with the ticks it spent trying recorded")

-- The settle bound is a bound on CONVERGING, not on being converged. A trial
-- runs for as long as its program takes, and a stage that failed itself part
-- way through one would report a reset failure in the middle of an injection.
local long = SF.new(cfg({ settle_timeout_ticks = 20 }))
long:start()
local lgcmds = drive(long, ordinary(80))
t.eq(first_state(lgcmds, S.READY), ready_at,
     "a stage that settles inside the bound is ready")
local failed_later = 0
for i = ready_at, #lgcmds do
    if lgcmds[i].state ~= S.READY then failed_later = failed_later + 1 end
end
t.eq(failed_later, 0,
     "and stays ready however long the trial runs afterwards, bound or no bound")

-- --- the game resets the stage on its own ------------------------------------

t.group("a refresh the game raises mid-trial abandons the trial")

local mid = SF.new(cfg())
mid:start()
local mcmds = drive(mid, script(40, function(i)
    if i >= 2 and i <= 4 then return { refreshing = true } end
    if i >= 20 then return { refreshing = true } end
    return nil
end))
local mres = mid:result()
t.eq(mres.outcome, "abandoned", "the reset reports the trial as abandoned")
t.ok(mres.outcome ~= "failed", "which is not the same fact as a reset that failed")
t.eq(mcmds[20].state, S.ABANDONED, "on the tick the flag came back up")
t.ok(mres.reason:find("underneath") ~= nil,
     "and says the stage moved underneath the trial: " .. tostring(mres.reason))
t.eq(mcmds[21].inject_allowed, false, "nothing may be injected afterwards")
t.eq(mcmds[25].outcome, "abandoned",
     "and the outcome stays abandoned however long it is ticked")

-- The same during settling, before anything was ever ready.
local mid2 = SF.new(cfg())
mid2:start()
drive(mid2, script(40, function(i)
    if i >= 2 and i <= 4 then return { refreshing = true } end
    if i == 9 then return { refreshing = true } end
    return nil
end))
t.eq(mid2:result().outcome, "abandoned",
     "a refresh during settling abandons too, rather than restarting quietly")

-- --- pinning -----------------------------------------------------------------

t.group("pinned resources are verified, not assumed")

local late = SF.new(cfg())
late:start()
local lcmds = drive(late, script(40, function(i)
    if i >= 2 and i <= 4 then return { refreshing = true } end
    if i < 10 then return { attacker_hp = 4200 } end
    return nil
end))
t.ok(count_state(lcmds, S.PIN) > 1, "PIN keeps writing until the values read back")
t.eq(late:result().pinned, true, "and only then reports the pin as having held")
t.ok(first_state(lcmds, S.READY) > ready_at,
     "a pin that takes time makes the reset take time")

local odd = SF.new(cfg({ pin = { attacker_hp = 10000, mystery_gauge = 3 } }))
odd:start()
drive(odd, ordinary())
local ores = odd:result()
t.eq(ores.pinned, true,
     "a pin field with nothing to check it against does not block the reset")
local unverifiable = ores.unverifiable_pin_fields
t.ok(unverifiable ~= nil and unverifiable[1] == "mystery_gauge",
     "but it is reported as unverifiable: written and checked are different facts")

local nothing = SF.new(cfg({ pin = false, target_positions = false }))
nothing:start()
local ncmds2 = drive(nothing, ordinary())
local nres2 = nothing:result()
t.eq(nres2.outcome, "ready",
     "a reset that knowingly corrects and pins nothing still settles")
t.eq(nres2.corrected, false, "and records that no correction was attempted")
t.eq(nres2.pinned, false, "and that nothing was pinned")
local wrote = 0
for _, c in ipairs(ncmds2) do
    if c.pin_resources ~= nil or c.correct_position ~= nil then wrote = wrote + 1 end
end
t.eq(wrote, 0, "with no resource or position write emitted anywhere")

-- --- degenerate input --------------------------------------------------------

t.group("degenerate input")

local unstarted = SF.new(cfg())
local ucmd = unstarted:tick(snap())
t.eq(ucmd.state, S.IDLE, "a machine nobody started stays idle")
t.eq(ucmd.inject_allowed, false, "and allows nothing to be injected")
t.eq(ucmd.request_refresh, nil, "and asks for nothing")

local nilsnap = SF.new(cfg())
nilsnap:start()
nilsnap:tick(nil)
nilsnap:tick(nil)
local nsres = nilsnap:result()
t.eq(nsres.ticks_total, 0, "a tick with no snapshot at all does not advance the machine")
t.eq(nsres.unresolved_ticks, 2, "but is counted, so a blind run is visible")

-- Restarting has to start from zero, or one trial's settle time is the sum of
-- every trial before it.
local reused = SF.new(cfg())
reused:start()
drive(reused, ordinary())
reused:start()
local rcmds = drive(reused, ordinary())
t.eq(first_state(rcmds, S.READY), ready_at,
     "a reused machine resets every counter it keeps")
t.eq(reused:result().ticks_to_ready, ready_at, "so the second trial reports its own cost")

return t.finish()
