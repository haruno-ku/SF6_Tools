-- Unit tests for func/ComboExplorer/core/LinkVerdict.lua
--
-- The verdict this module produces is the entire dataset. Every row in the
-- eventual edge graph is one of these, so a systematic error here is a
-- systematic error in the project's output - and the failure mode is a
-- confident negative, not a crash.
--
-- The case the project owner called out specifically: judging on
-- "combo_cnt went 1 -> 2" breaks on every multi-hit move. Those are asserted
-- first.

local t = require("tests.lua.harness")
local LV = require("func/ComboExplorer/core/LinkVerdict")

local function snap(over)
    local s = { combo_count = 0, guard_count = 0, attacker_action_id = 1, attacker_hitstop = 0 }
    for k, v in pairs(over or {}) do s[k] = v end
    return s
end

-- Runs a scripted trial. `stream` entries may carry `inject = "a"|"b"`.
local function run(spec, stream)
    local trial = LV.new(spec)
    for i, s in ipairs(stream) do
        if s.inject then trial:mark_injected(s.inject, i) end
        trial:tick(s, i)
    end
    return trial:result()
end

local A, B = 604, 621

-- --- the ordinary link -------------------------------------------------------

t.group("a plain link")

local r = run({ expected_a = { A }, expected_b = { B } }, {
    snap({ inject = "a" }),
    snap({ attacker_action_id = A }),
    snap({ attacker_action_id = A, combo_count = 1 }),
    snap({ attacker_action_id = A, combo_count = 1, inject = "b" }),
    snap({ attacker_action_id = B, combo_count = 1 }),
    snap({ attacker_action_id = B, combo_count = 2 }),
    snap({ attacker_action_id = 1, combo_count = 2 }),
})
t.eq(r.verdict, "link", "A into B is a link")
t.eq(r.hits_added, 1, "one hit attributed to B")
t.eq(r.combo_before_b, 1, "the counter before B is recorded")
t.eq(r.a_action_id, A, "A's action id recorded")
t.eq(r.b_action_id, B, "B's action id recorded")

-- --- the multi-hit case the fixed 1 -> 2 test gets wrong ---------------------

t.group("multi-hit A")

-- A hits three times on its own. A rule of "the counter must read 2 after B"
-- would call this a failure; the counter is at 3 before B even starts.
r = run({ expected_a = { A }, expected_b = { B } }, {
    snap({ inject = "a" }),
    snap({ attacker_action_id = A, combo_count = 1 }),
    snap({ attacker_action_id = A, combo_count = 2 }),
    snap({ attacker_action_id = A, combo_count = 3, inject = "b" }),
    snap({ attacker_action_id = B, combo_count = 3 }),
    snap({ attacker_action_id = B, combo_count = 4 }),
})
t.eq(r.verdict, "link", "a three-hit A still links")
t.eq(r.combo_before_b, 3, "the counter before B was already 3")
t.eq(r.hits_added, 1, "and B added one")

t.group("multi-hit B")

r = run({ expected_a = { A }, expected_b = { B } }, {
    snap({ inject = "a" }),
    snap({ attacker_action_id = A, combo_count = 1, inject = "b" }),
    snap({ attacker_action_id = B, combo_count = 1 }),
    snap({ attacker_action_id = B, combo_count = 2 }),
    snap({ attacker_action_id = B, combo_count = 3 }),
})
t.eq(r.verdict, "link", "a multi-hit B links")
t.eq(r.hits_added, 2, "and its hit count is recorded, not just the fact of a link")

-- --- attribution -------------------------------------------------------------

t.group("the rise must be attributable to B")

-- A is still connecting after B was pressed but before B's action appears.
-- Counting that rise would credit B with A's hits.
r = run({ expected_a = { A }, expected_b = { B } }, {
    snap({ inject = "a" }),
    snap({ attacker_action_id = A, combo_count = 1 }),
    snap({ attacker_action_id = A, combo_count = 2, inject = "b" }),
    snap({ attacker_action_id = A, combo_count = 3 }),   -- still A, still hitting
    snap({ attacker_action_id = B, combo_count = 3 }),
    snap({ attacker_action_id = B, combo_count = 3 }),   -- B touched nothing
})
t.eq(r.verdict, "whiff", "a rise before B's action appeared is not credited to B")
t.eq(r.combo_before_b, 3, "the baseline is the counter as B began")
t.eq(r.hits_added, 0, "so B added nothing")

-- --- the failure modes -------------------------------------------------------

t.group("A never hit")

r = run({ expected_a = { A }, expected_b = { B } }, {
    snap({ inject = "a" }),
    snap({ attacker_action_id = A }),
    snap({ attacker_action_id = A, inject = "b" }),
    snap({ attacker_action_id = B }),
})
t.eq(r.verdict, "a_failed", "if A never hit, B was never a fair test")
t.ok(r.reason:find("never hit", 1, true) ~= nil, "and the reason distinguishes it from not coming out")

r = run({ expected_a = { A }, expected_b = { B } }, {
    snap({ inject = "a" }),
    snap({ attacker_action_id = 1 }),
    snap({ attacker_action_id = 1 }),
})
t.eq(r.verdict, "a_failed", "A never coming out is also a_failed")
t.ok(r.reason:find("never came out", 1, true) ~= nil, "with its own reason")

t.group("wrong move")

-- The input produced something else. That is a finding about the input map,
-- not a statement about whether the two moves link.
r = run({ expected_a = { A }, expected_b = { B } }, {
    snap({ inject = "a" }),
    snap({ attacker_action_id = A, combo_count = 1 }),
    snap({ attacker_action_id = A, combo_count = 1, inject = "b" }),
    snap({ attacker_action_id = 999, combo_count = 1 }),
    snap({ attacker_action_id = 999, combo_count = 2 }),
})
t.eq(r.verdict, "wrong_move", "an unexpected action is not a link")
t.eq_list(r.unexpected_action_ids, { 999 }, "and the report names what came out")

t.group("blocked")

r = run({ expected_a = { A }, expected_b = { B } }, {
    snap({ inject = "a" }),
    snap({ attacker_action_id = A, combo_count = 1 }),
    snap({ attacker_action_id = A, combo_count = 1, inject = "b" }),
    snap({ attacker_action_id = B, combo_count = 1, guard_count = 0 }),
    snap({ attacker_action_id = B, combo_count = 1, guard_count = 1 }),
})
t.eq(r.verdict, "blocked", "a guarded B is blocked, not a whiff")
t.eq(r.guard_rise, 1, "and the guard rise is recorded")

t.group("combo broke")

r = run({ expected_a = { A }, expected_b = { B } }, {
    snap({ inject = "a" }),
    snap({ attacker_action_id = A, combo_count = 1 }),
    snap({ attacker_action_id = A, combo_count = 0 }),   -- dropped
    snap({ attacker_action_id = A, combo_count = 0, inject = "b" }),
    snap({ attacker_action_id = B, combo_count = 0 }),
    snap({ attacker_action_id = B, combo_count = 1 }),   -- a NEW combo
})
t.eq(r.verdict, "combo_broke", "B starting a fresh combo is not a link")

-- --- the post-reset grace ----------------------------------------------------

t.group("the counter is not believed during the grace window")

-- Upstream distrusts the combo counter for 15 frames after a reset because it
-- can still be reading the previous trial. Believing it there records a
-- phantom link from a stale number.
r = run({ expected_a = { A }, expected_b = { B }, grace_ticks = 3 }, {
    snap({ combo_count = 7 }),                            -- stale
    snap({ combo_count = 7 }),                            -- stale
    snap({ combo_count = 7 }),                            -- stale
    snap({ combo_count = 0, inject = "a" }),
    snap({ attacker_action_id = A, combo_count = 1 }),
    snap({ attacker_action_id = A, combo_count = 1, inject = "b" }),
    snap({ attacker_action_id = B, combo_count = 2 }),
})
t.eq(r.verdict, "link", "the stale reading did not corrupt the trial")
t.eq(r.combo_before_b, 1, "the baseline came from real observations only")

-- --- ambiguous action ids ----------------------------------------------------

t.group("expected ids are a set, not a single value")

-- 617/618/619 all display as crouching light and the catalog refuses to say
-- which one an input produces, so the trial must accept any of them.
r = run({ expected_a = { 617, 618, 619 }, expected_b = { B } }, {
    snap({ inject = "a" }),
    snap({ attacker_action_id = 619, combo_count = 1 }),
    snap({ attacker_action_id = 619, combo_count = 1, inject = "b" }),
    snap({ attacker_action_id = B, combo_count = 2 }),
})
t.eq(r.verdict, "link", "any id in the group counts as A")
t.eq(r.a_action_id, 619, "and the one that actually came out is recorded")

-- --- latency is collected for free -------------------------------------------

t.group("injection latency")

r = run({ expected_a = { A }, expected_b = { B } }, {
    snap({ inject = "a" }),                               -- tick 1
    snap({}),
    snap({ attacker_action_id = A, combo_count = 1 }),    -- tick 3
    snap({ attacker_action_id = A, combo_count = 1, inject = "b" }),  -- tick 4
    snap({ attacker_action_id = A, combo_count = 1 }),
    snap({ attacker_action_id = B, combo_count = 2 }),    -- tick 6
})
t.eq(r.a_latency_ticks, 2, "A took two ticks to appear")
t.eq(r.b_latency_ticks, 2, "B took two ticks to appear")

-- --- nothing observed --------------------------------------------------------

t.group("nothing observed")

local trial = LV.new({ expected_a = { A }, expected_b = { B } })
trial:tick(nil, 1)
trial:tick(nil, 2)
r = trial:result()
t.eq(r.verdict, "inconclusive", "unresolvable ticks are not a verdict")
t.eq(r.unresolved_ticks, 2, "and they are counted")

-- --- aggregating repeats -----------------------------------------------------

t.group("aggregate")

local function res(verdict, over)
    local x = { verdict = verdict, hits_added = 1 }
    for k, v in pairs(over or {}) do x[k] = v end
    return x
end

local agg = LV.aggregate({ res("link"), res("link"), res("link") })
t.eq(agg.verdict, "link", "three links is a link")
t.ok(agg.stable, "and it is stable")
t.eq(agg.hits_added, 1, "with a consistent hit count")

agg = LV.aggregate({ res("link"), res("whiff"), res("link") })
t.eq(agg.verdict, "link", "a link that happened twice is still recorded as a link")
t.eq(agg.stable, false, "but NOT as stable")
t.ok(agg.reason:find("unstable", 1, true) ~= nil, "and the reason says so")

agg = LV.aggregate({ res("link", { hits_added = 1 }), res("link", { hits_added = 2 }),
                     res("link", { hits_added = 1 }) })
t.eq(agg.hits_added, "varies", "an inconsistent hit count is reported as varying")

agg = LV.aggregate({ res("a_failed"), res("a_failed") })
t.eq(agg.verdict, "a_failed", "A failing every time is its own outcome")

agg = LV.aggregate({ res("blocked"), res("blocked"), res("whiff") })
t.eq(agg.verdict, "blocked", "the dominant non-link outcome is named")
t.ok(agg.reason:find("2 of 3", 1, true) ~= nil, "with its share")

agg = LV.aggregate({})
t.eq(agg.verdict, "inconclusive", "no attempts is not a result")

return t.finish()
