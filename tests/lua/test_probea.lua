-- Unit tests for func/ComboExplorer/core/ProbeA.lua
--
-- Probe A decides whether mComboDamage can be trusted, and that decision gates
-- the whole scoring phase. A review found two ways it could produce a confident
-- wrong answer before the code ever ran: measuring the HP baseline after the
-- first hit (so the two damage sources disagree on every sample), and counting
-- idle ticks through hitstop (so combos merge or split). Both are asserted
-- here, against snapshot streams that would be tedious to reproduce by hand on
-- a real machine.

local t = require("tests.lua.harness")
local ProbeA = require("func/ComboExplorer/core/ProbeA")

-- A snapshot as GameAdapter.snapshot() would return it.
local function snap(over)
    local s = {
        combo_count = 0,
        combo_damage_attacker = 0,
        combo_damage_victim = nil,
        victim_hp = 10000,
        victim_hp_max = 10000,
        attacker_hitstop = 0,
        attacker_action_id = 100,
        attacker_action_frame = 1,
        attacker_rl_dir_raw = true,
        attacker_rl_dir_type = "boolean",
    }
    for k, v in pairs(over or {}) do s[k] = v end
    return s
end

local function feed(p, stream)
    local closed = {}
    for i, s in ipairs(stream) do
        local sample = p:tick(s, i)
        if sample then closed[#closed + 1] = sample end
    end
    return closed
end

-- --- the baseline bug the review caught -------------------------------------

t.group("HP baseline spans the first hit")

-- Idle first, so a pre-combo baseline exists. Then a 2-hit combo worth 1500,
-- 800 of it on the first hit. If the baseline were taken when combo_count
-- first went above zero, the delta would be 700 and disagree with 1500 on
-- every single sample - which would read as "mComboDamage is untrustworthy".
local p = ProbeA.new({ idle_ticks_to_close = 3 })
local stream = {
    snap({ combo_count = 0, victim_hp = 10000 }),
    snap({ combo_count = 0, victim_hp = 10000 }),
    snap({ combo_count = 1, victim_hp = 9200, combo_damage_attacker = 800 }),
    snap({ combo_count = 2, victim_hp = 8500, combo_damage_attacker = 1500 }),
    snap({ combo_count = 0, victim_hp = 8500, combo_damage_attacker = 0 }),
    snap({ combo_count = 0, victim_hp = 8500 }),
    snap({ combo_count = 0, victim_hp = 8500 }),
}
local closed = feed(p, stream)

t.eq(#closed, 1, "one combo closed")
local s = closed[1]
t.eq(s.victim_hp_at_start, 10000, "the baseline is the health BEFORE the first hit")
t.eq(s.hp_delta, 1500, "so the delta spans the whole combo")
t.eq(s.combo_damage, 1500, "matching the field")
t.eq(s.agree, true, "and the two agree, as they should")
t.eq(s.hits, 2, "hit count recorded")

-- --- hitstop must not close a combo -----------------------------------------

t.group("idle ticks are not counted during hitstop")

-- A juggle: the counter drops to 0 for a moment while the game is frozen in
-- hitstop, then the combo continues. Counting those frozen ticks as idle would
-- split one combo into two, and the second half would report a near-zero HP
-- delta against a resolved field - printing as a disagreement.
p = ProbeA.new({ idle_ticks_to_close = 3 })
closed = feed(p, {
    snap({ combo_count = 0, victim_hp = 10000 }),
    snap({ combo_count = 1, victim_hp = 9000, combo_damage_attacker = 1000 }),
    snap({ combo_count = 0, victim_hp = 9000, combo_damage_attacker = 1000, attacker_hitstop = 8 }),
    snap({ combo_count = 0, victim_hp = 9000, combo_damage_attacker = 1000, attacker_hitstop = 7 }),
    snap({ combo_count = 0, victim_hp = 9000, combo_damage_attacker = 1000, attacker_hitstop = 6 }),
    snap({ combo_count = 0, victim_hp = 9000, combo_damage_attacker = 1000, attacker_hitstop = 5 }),
    snap({ combo_count = 2, victim_hp = 8200, combo_damage_attacker = 1800 }),
    snap({ combo_count = 0, victim_hp = 8200, combo_damage_attacker = 0 }),
    snap({ combo_count = 0, victim_hp = 8200 }),
    snap({ combo_count = 0, victim_hp = 8200 }),
})

t.eq(#closed, 1, "the hitstop gap did not split the combo in two")
t.eq(closed[1].hits, 2, "both hits are in the one sample")
t.eq(closed[1].hp_delta, 1800, "and the delta spans the whole thing")
t.ok(closed[1].hitstop_ticks >= 4, "hitstop ticks are recorded on the sample")

-- The threshold that was used is recorded too, so a different one can be tried
-- against data that has already been collected.
t.eq(closed[1].idle_ticks_threshold, 3, "the threshold in force is recorded")
t.eq(closed[1].idle_ticks_at_close, 3, "as is how many idle ticks actually closed it")

-- --- a genuine gap does close it ---------------------------------------------

t.group("a real gap still closes the combo")

p = ProbeA.new({ idle_ticks_to_close = 3 })
closed = feed(p, {
    snap({ combo_count = 0, victim_hp = 10000 }),
    snap({ combo_count = 1, victim_hp = 9000, combo_damage_attacker = 1000 }),
    snap({ combo_count = 0, victim_hp = 9000, combo_damage_attacker = 0 }),
    snap({ combo_count = 0, victim_hp = 9000 }),
    snap({ combo_count = 0, victim_hp = 9000 }),
    snap({ combo_count = 1, victim_hp = 8300, combo_damage_attacker = 700 }),
    snap({ combo_count = 0, victim_hp = 8300, combo_damage_attacker = 0 }),
    snap({ combo_count = 0, victim_hp = 8300 }),
    snap({ combo_count = 0, victim_hp = 8300 }),
})
t.eq(#closed, 2, "two separate combos")
t.eq(closed[1].hp_delta, 1000, "first measured from its own baseline")
t.eq(closed[2].victim_hp_at_start, 9000, "second baseline is the health after the first combo")
t.eq(closed[2].hp_delta, 700, "so the second delta is its own damage only")

-- --- unresolvable ticks do not close a combo --------------------------------

t.group("scene changes are skipped, not treated as idle")

-- During a round transition the players may not resolve. Treating those as
-- idle ticks would close an in-flight combo on a scene change. Fed one tick at
-- a time because a nil cannot be carried through a stream table.
p = ProbeA.new({ idle_ticks_to_close = 3 })
p:tick(snap({ combo_count = 0, victim_hp = 10000 }), 1)
p:tick(snap({ combo_count = 1, victim_hp = 9000, combo_damage_attacker = 1000 }), 2)
t.is_nil(p:tick(nil, 3), "an unresolvable tick returns nothing")
t.is_nil(p:tick(nil, 4), "and again")
t.is_nil(p:tick(nil, 5), "and again - three of them, past the threshold")
t.ok(p.in_combo, "the combo is still open")
t.eq(p.skipped_ticks, 3, "and the skipped ticks are counted")

-- A snapshot with no combo counter is equally unusable.
t.is_nil(p:tick({ victim_hp = 9000 }, 6), "a snapshot with no combo count is skipped")
t.eq(p.skipped_ticks, 4, "counted as skipped")

-- --- flush ---------------------------------------------------------------

t.group("flush")

p = ProbeA.new({ idle_ticks_to_close = 20 })
p:tick(snap({ combo_count = 0, victim_hp = 10000 }), 1)
p:tick(snap({ combo_count = 1, victim_hp = 9000, combo_damage_attacker = 1000 }), 2)
local flushed = p:flush(3)
t.ok(flushed ~= nil, "stopping the probe mid-combo still yields the sample")
t.eq(flushed.closed_by, "flush", "marked as flushed rather than closed normally")
t.eq(flushed.hp_delta, 1000, "with its measurement intact")
t.is_nil(p:flush(4), "flushing again yields nothing")

-- --- action id collection ----------------------------------------------------

t.group("action ids are collected for the canonical question")

p = ProbeA.new({ idle_ticks_to_close = 2 })
feed(p, {
    snap({ combo_count = 0, victim_hp = 10000, attacker_action_id = 1 }),
    snap({ combo_count = 1, victim_hp = 9500, combo_damage_attacker = 500, attacker_action_id = 617 }),
    snap({ combo_count = 1, victim_hp = 9500, combo_damage_attacker = 500, attacker_action_id = 617 }),
    snap({ combo_count = 2, victim_hp = 9000, combo_damage_attacker = 1000, attacker_action_id = 621 }),
    snap({ combo_count = 0, victim_hp = 9000, combo_damage_attacker = 0,   attacker_action_id = 1 }),
    snap({ combo_count = 0, victim_hp = 9000, attacker_action_id = 1 }),
})

local sample = p.samples[1]
t.ok(sample ~= nil, "a sample closed")
local ids = {}
for _, tr in ipairs(sample.action_transitions) do ids[#ids + 1] = tr.action_id end
t.eq_list(ids, { 617, 621, 1 }, "one entry per action change, repeats collapsed")

local hist = p:action_id_histogram()
t.ok(#hist >= 3, "the histogram covers every id seen")

-- --- the report --------------------------------------------------------------

t.group("report")

p = ProbeA.new({ idle_ticks_to_close = 2 })
for i = 1, 3 do
    local base = 10000 - (i - 1) * 1500
    feed(p, {
        snap({ combo_count = 0, victim_hp = base }),
        snap({ combo_count = 1, victim_hp = base - 700,  combo_damage_attacker = 700 }),
        snap({ combo_count = 2, victim_hp = base - 1500, combo_damage_attacker = 1500 }),
        snap({ combo_count = 0, victim_hp = base - 1500, combo_damage_attacker = 0 }),
        snap({ combo_count = 0, victim_hp = base - 1500 }),
    })
end

local rep = p:report()
t.eq(rep.probe, "A.damage_readability", "the report names itself")
t.eq(#rep.samples, 3, "three samples")
t.eq(rep.counts.comparable, 3, "all three comparable")
t.eq(rep.recommended_source, "combo_damage", "and the field is endorsed")
t.ok(rep.sufficient, "with enough samples to act on")
t.eq(rep.idle_ticks_to_close, 2, "the threshold used is stated in the report")

-- An empty run must not look like a conclusion.
local empty = ProbeA.new():report()
t.eq(empty.recommended_source, "undecided", "no samples decides nothing")
t.eq(#empty.samples, 0, "and reports no samples")

-- --- the failing build --------------------------------------------------------

t.group("a build where the field never resolves")

p = ProbeA.new({ idle_ticks_to_close = 2 })
for i = 1, 3 do
    local base = 10000 - (i - 1) * 1200
    feed(p, {
        { combo_count = 0, victim_hp = base, attacker_hitstop = 0 },
        { combo_count = 1, victim_hp = base - 1200, attacker_hitstop = 0 },
        { combo_count = 0, victim_hp = base - 1200, attacker_hitstop = 0 },
        { combo_count = 0, victim_hp = base - 1200, attacker_hitstop = 0 },
    })
end
rep = p:report()
t.eq(rep.recommended_source, "hp_delta", "an unreadable field sends the project to the HP delta")
t.is_nil(rep.samples[1].combo_damage, "and the damage figure is nil, not a misleading 0")
t.eq(rep.samples[1].hp_delta, 1200, "while the HP delta still measured the combo")

return t.finish()
