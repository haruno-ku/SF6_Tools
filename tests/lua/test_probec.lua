-- Unit tests for func/ComboExplorer/core/ProbeC.lua
--
-- Probe C measures what a stage reset costs, by watching the operator reset
-- from the training menu. That number decides how large the brute-force matrix
-- can be - there is no way to run the game faster - and it also settles
-- Provenance.reset_settle_ticks, which is currently a guess arrived at by
-- adding two of upstream's own numbers together.

local t = require("tests.lua.harness")
local ProbeC = require("func/ComboExplorer/core/ProbeC")

local function obs(over)
    local o = { refreshing = false, combo_count = 0,
                attacker_act_st = 0, victim_act_st = 0,
                attacker_pos = -1.5, victim_pos = 1.5, wall_clock = 0 }
    for k, v in pairs(over or {}) do o[k] = v end
    return o
end

-- Plays one reset: idle, the flag rises for `refresh_len`, then the stage
-- wobbles for `wobble` ticks before settling.
local function do_reset(p, start_tick, refresh_len, wobble, wall_per_tick)
    local tick = start_tick
    local wall = start_tick * (wall_per_tick or 0.016)
    local done = nil

    for _ = 1, refresh_len do
        done = p:tick(obs({ refreshing = true, wall_clock = wall }), tick) or done
        tick = tick + 1
        wall = wall + (wall_per_tick or 0.016)
    end
    -- Positions still moving: not settled.
    for i = 1, wobble do
        done = p:tick(obs({ attacker_pos = -1.5 - i * 0.5, wall_clock = wall }), tick) or done
        tick = tick + 1
        wall = wall + (wall_per_tick or 0.016)
    end
    -- Stable.
    for _ = 1, 10 do
        done = p:tick(obs({ wall_clock = wall }), tick) or done
        tick = tick + 1
        wall = wall + (wall_per_tick or 0.016)
    end
    return done, tick
end

-- --- one reset ---------------------------------------------------------------

t.group("one reset")

local p = ProbeC.new({ stable_ticks = 3 })
local e = do_reset(p, 100, 12, 5)

t.ok(e ~= nil, "the episode closed")
t.eq(e.refresh_ticks, 12, "the refresh flag was up for twelve ticks")
t.ok(e.settle_ticks > 0, "and settling took additional ticks after it cleared")
t.ok(e.total_ticks > e.refresh_ticks,
     "the total is longer than the flag - a reset is not an instant")
t.ok(e.total_wall_ms > 0, "wall-clock time is recorded")

-- --- the flag clearing is not the end ----------------------------------------

t.group("settling is measured separately from the flag")

-- This is the whole point. Upstream raises the flag, polls until it clears,
-- and only then applies the position correction - and separately refuses to
-- believe the combo counter for another fifteen frames. Timing only the flag
-- would report a reset as far cheaper, and far more finished, than it is.
p = ProbeC.new({ stable_ticks = 5 })
e = do_reset(p, 1, 8, 30)
t.eq(e.refresh_ticks, 8, "the flag was brief")
t.ok(e.settle_ticks >= 30, "but settling took much longer (" .. e.settle_ticks .. ")")

-- --- a combo still running is not settled ------------------------------------

t.group("settle conditions")

p = ProbeC.new({ stable_ticks = 3 })
local tick = 1
p:tick(obs({ refreshing = true }), tick); tick = tick + 1
p:tick(obs({ refreshing = false }), tick); tick = tick + 1
-- Stable positions, but the counter is still reading the previous trial.
for _ = 1, 10 do
    p:tick(obs({ combo_count = 4 }), tick); tick = tick + 1
end
t.eq(#p.episodes, 0, "a running combo counter means not settled")

for _ = 1, 10 do
    p:tick(obs({ combo_count = 0 }), tick); tick = tick + 1
end
t.eq(#p.episodes, 1, "once the counter is clear it settles")

-- An action still in progress is equally not settled.
p = ProbeC.new({ stable_ticks = 3 })
tick = 1
p:tick(obs({ refreshing = true }), tick); tick = tick + 1
p:tick(obs({ refreshing = false }), tick); tick = tick + 1
for _ = 1, 10 do
    p:tick(obs({ attacker_act_st = 12 }), tick); tick = tick + 1
end
t.eq(#p.episodes, 0, "a player mid-action means not settled")

-- --- several resets ----------------------------------------------------------

t.group("conclude")

p = ProbeC.new({ stable_ticks = 3 })
local at = 1
for i = 1, 6 do
    local _, next_tick = do_reset(p, at, 10 + i, 4)
    at = next_tick + 5
end
t.eq(#p.episodes, 6, "six resets recorded")

local c = ProbeC.conclude(p.episodes)
t.ok(c.sufficient, "six is enough to act on")
t.ok(c.total_ticks.min < c.total_ticks.max, "the spread is reported, not just a mean")
t.ok(c.verdict:find("settles in", 1, true) ~= nil, "and stated in words")

-- The suggestion is the worst case, not the average: a settle gate that is
-- right on average starts half its trials against a stale counter.
t.eq(c.suggested_settle_ticks, c.total_ticks.max, "the suggestion is the maximum observed")
t.ok(c.suggested_note:find("half its trials", 1, true) ~= nil, "and says why")

-- --- not enough data ---------------------------------------------------------

t.group("not enough data")

c = ProbeC.conclude({})
t.eq(c.episodes, 0, "no episodes")
t.eq(c.sufficient, false, "not sufficient")
t.ok(c.verdict:find("reset from the training menu", 1, true) ~= nil,
     "and the operator is told what to do")

c = ProbeC.conclude({ { total_ticks = 40, refresh_ticks = 10, settle_ticks = 30 } })
t.eq(c.sufficient, false, "one episode is not enough")
t.ok(c.verdict:find("only 1", 1, true) ~= nil, "and the verdict says how many there were")
t.is_nil(c.suggested_settle_ticks, "no suggestion is offered from one sample")

-- --- degenerate input --------------------------------------------------------

t.group("degenerate input")

p = ProbeC.new()
t.is_nil(p:tick(nil, 1), "a nil observation is ignored")
t.is_nil(p:tick("nonsense", 2), "so is a non-table")
t.eq(p.ticks, 0, "and neither is counted")

return t.finish()
