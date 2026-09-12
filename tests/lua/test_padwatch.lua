-- Unit tests for func/ComboExplorer/core/PadWatch.lua
--
-- This module exists because the derivation it replaces threw away a real
-- measurement. Measured on build 24176760: bit 0x40 was pressed alone, an
-- action came out, and the action's notation had TWO tokens ("AUTO + 强"), so
-- the single-button matcher found nothing and the bit was reported unwitnessed.
-- The press happened and the evidence was discarded by the matching rule.
--
-- So the assertions here are mostly about not doing that: record what was seen,
-- keep a two-button mask distinguishable from two one-button presses, and name
-- nothing.

local t = require("tests.lua.harness")
local PW = require("func/ComboExplorer/core/PadWatch")

-- --- what it records ---------------------------------------------------------

t.group("a press is recorded with what came out of it")

do
    local w = PW.new()
    for _ = 1, 5 do PW.observe(w, 0x40, 660) end
    local rep = PW.report(w)
    t.eq(#rep.rows, 1, "one mask was seen")
    t.eq(rep.rows[1].mask, 0x40, "the mask itself")
    t.eq(rep.rows[1].ticks, 5, "held for five ticks")
    t.eq(rep.rows[1].presses, 1, "which is ONE press, not five")
    t.eq(rep.rows[1].top_action_id, 660, "and the action it produced")
    t.ok(rep.rows[1].single_bit, "0x40 is one bit, so it names a button")
end

do
    -- The count that matters: a long hold is one data point. Counting ticks as
    -- presses would make leaning on a button look like repeated confirmation.
    local w = PW.new()
    for _ = 1, 3 do PW.observe(w, 0x40, 660) end
    PW.observe(w, 0, nil)
    for _ = 1, 3 do PW.observe(w, 0x40, 660) end
    t.eq(PW.report(w).rows[1].presses, 2, "released and pressed again is two")
end

-- --- the distinction the union would lose -------------------------------------

t.group("two buttons held together is not two presses")

do
    -- A bit-union answers "was 0x40 ever set" and nothing else. The operator
    -- is asked to press ONE thing, so a mask with two bits in it has to stay
    -- visible as what it is.
    local w = PW.new()
    for _ = 1, 5 do PW.observe(w, 0x40 | 0x100, 660) end
    local rep = PW.report(w)
    t.eq(#rep.rows, 1, "one mask")
    t.eq(rep.rows[1].mask, 0x140, "with both bits in it")
    t.eq(#rep.rows[1].bits, 2, "and it says there are two")
    t.eq(rep.rows[1].single_bit, false, "so it does not name a button")
    t.eq(#PW.single_bits(w), 0, "and it is not offered as one")
end

do
    local w = PW.new()
    for _ = 1, 5 do PW.observe(w, 0x40, 660) end
    PW.observe(w, 0, nil)
    for _ = 1, 5 do PW.observe(w, 0x100, 500) end
    local singles = PW.single_bits(w)
    t.eq(#singles, 2, "two separate presses ARE two nameable buttons")
    t.eq(singles[1].mask, 0x40, "in the order they were pressed")
    t.eq(singles[2].mask, 0x100, "not sorted by value")
end

-- --- directions are not buttons ----------------------------------------------

t.group("the stick does not create a new mask on every tick")

do
    -- Holding a direction while pressing would otherwise make each direction a
    -- different mask value and bury the button.
    local w = PW.new()
    PW.observe(w, 0x40 | 0x01, 660)   -- up
    PW.observe(w, 0x40 | 0x02, 660)   -- down
    PW.observe(w, 0x40 | 0x08, 660)   -- right
    local rep = PW.report(w)
    t.eq(#rep.rows, 1, "the direction bits are masked off")
    t.eq(rep.rows[1].mask, 0x40, "leaving the button")
    t.eq(rep.rows[1].presses, 1, "and it is still one press")
end

do
    local w = PW.new()
    PW.observe(w, 0x08, 1)
    t.eq(#PW.report(w).rows, 0, "a direction with no button is not a press")
end

-- --- unreadable is not zero ---------------------------------------------------

t.group("a pad that could not be read is not a pad at rest")

do
    local w = PW.new()
    PW.observe(w, nil, nil)
    PW.observe(w, nil, nil)
    local rep = PW.report(w)
    t.eq(rep.unreadable, 2, "counted as unreadable")
    t.eq(#rep.rows, 0, "and NOT as a press of nothing")
    t.eq(rep.ticks, 2, "while the ticks still passed")
end

-- --- the transient masks a pad passes through ---------------------------------

t.group("a mask nobody meant to press is recorded but not led with")

do
    -- Pressing two buttons by hand never lands both on the same frame, so a
    -- one-tick single-bit mask appears on the way in. It is real and it is
    -- recorded - but offering it as "this bit is that button" would name a
    -- button from a press that did not happen.
    local w = PW.new()
    PW.observe(w, 0x40, 660)                                   -- on the way in
    for _ = 1, 20 do PW.observe(w, 0x40 | 0x100, 700) end      -- what was meant
    local rep = PW.report(w)
    t.eq(#rep.rows, 2, "both masks are in the record")
    t.eq(rep.rows[1].settled, false, "the one-tick one is not settled")
    t.eq(rep.rows[2].settled, true, "the held one is")
    t.eq(#PW.single_bits(w), 0, "so nothing unsettled is offered as a button")
end


-- --- a held button is mostly a character standing still ----------------------

t.group("what a mask produced is the first non-idle id, not the most-seen one")

-- Measured on build 24176760: 0x0010 held for 134 ticks reported action 1. The
-- move it produced lasts a dozen frames and the idle the character returns to
-- fills the rest, so the most-seen id IS the idle. Two of the operator's seven
-- presses read as "nothing came out" that way.

do
    local w = PW.new()
    -- Idle established with no button held, the way it is on the machine.
    for _ = 1, 30 do PW.observe(w, 0, 1) end
    t.eq(PW.idle_id(w), 1, "idle is measured, not assumed")

    for _ = 1, 6 do PW.observe(w, 0x10, 611) end       -- the move
    for _ = 1, 120 do PW.observe(w, 0x10, 1) end       -- back to standing
    local r = PW.report(w).rows[1]
    t.eq(r.top_action_id, 1, "the most-seen id really is the idle")
    t.eq(r.first_non_idle, 611, "but the first non-idle one is the move")
    t.eq(r.action_id, 611, "and that is what the row reports as produced")
end

do
    -- A button that genuinely produces nothing has no non-idle id, and must
    -- not be handed the idle as though it were an answer. Measured: 0x0200
    -- alone - the assist button - is exactly this.
    local w = PW.new()
    for _ = 1, 30 do PW.observe(w, 0, 1) end
    for _ = 1, 80 do PW.observe(w, 0x200, 1) end
    local r = PW.report(w).rows[1]
    t.is_nil(r.first_non_idle, "nothing but idle was ever seen")
    t.eq(r.action_id, 1, "so the row falls back to what there was")
    t.eq(PW.report(w).idle_action_id, 1, "with the idle named beside it")
end

do
    -- No idle sample at all: the operator started with a button already down.
    -- Every id is then a candidate, which is worse than knowing, and the report
    -- has to be readable as such rather than silently picking one.
    local w = PW.new()
    for _ = 1, 10 do PW.observe(w, 0x10, 611) end
    local rep = PW.report(w)
    t.is_nil(rep.idle_action_id, "no idle was measured")
    t.eq(rep.rows[1].first_non_idle, 611, "so the first id seen is taken as produced")
end


-- --- a press that began mid-move wears the previous move's id ----------------

t.group("only a press that started from a standing character is evidence")

-- Measured on build 24176760. The operator pressed 弱, then 中 before 弱's move
-- had finished, and the first non-idle id seen during the 中 press was 弱's move
-- still playing. The whole column shifted by one row: 0x0080 reported 611 and
-- 0x0100 reported 604, each mask wearing the action of the button pressed
-- before it. Every one of those readings names the wrong button.

do
    local w = PW.new()
    for _ = 1, 30 do PW.observe(w, 0, 1) end

    -- 弱, cleanly from standing.
    for _ = 1, 8 do PW.observe(w, 0x10, 611) end
    -- 中 pressed while 611 is STILL PLAYING - no idle in between.
    for _ = 1, 8 do PW.observe(w, 0x80, 611) end
    for _ = 1, 8 do PW.observe(w, 0x80, 604) end

    local rep = PW.report(w)
    local by_mask = {}
    for _, r in ipairs(rep.rows) do by_mask[r.mask] = r end

    t.eq(by_mask[0x10].from_idle, true, "the first press began from standing")
    t.eq(by_mask[0x10].first_non_idle, 611, "and its id is its own move")

    t.eq(by_mask[0x80].from_idle, false, "the second did not")
    t.is_nil(by_mask[0x80].first_non_idle,
             "so it offers no id - rather than offering 611, which is 弱's")
    t.eq(by_mask[0x80].dirty_action, 611,
         "what it DID see is kept, so the row does not look like a press that "
         .. "never registered")
end

do
    -- And a later clean press of the same mask fixes it. The operator should
    -- not have to clear and start over because one press was early.
    local w = PW.new()
    for _ = 1, 30 do PW.observe(w, 0, 1) end
    for _ = 1, 5 do PW.observe(w, 0x10, 611) end
    for _ = 1, 5 do PW.observe(w, 0x80, 611) end       -- early, contaminated
    for _ = 1, 20 do PW.observe(w, 0, 1) end           -- back to standing
    for _ = 1, 5 do PW.observe(w, 0x80, 604) end       -- clean
    local rep = PW.report(w)
    for _, r in ipairs(rep.rows) do
        if r.mask == 0x80 then
            t.eq(r.from_idle, true, "a later clean press arms the row")
            t.eq(r.first_non_idle, 604, "and it takes its own move")
        end
    end
end

-- --- it names nothing ---------------------------------------------------------

t.group("no catalog, no notation, no name")

do
    -- The whole point. What comes back is a mask and the action ids seen with
    -- it; calling that mask "AUTO" is a decision for whoever has the catalog,
    -- and doing it here would rebuild the inference this replaces.
    local w = PW.new()
    for _ = 1, 5 do PW.observe(w, 0x40, 660) end
    local r = PW.report(w).rows[1]
    t.is_nil(r.button, "the row carries no button name")
    t.is_nil(r.notation, "and no notation")
    t.eq(r.mask, 0x40, "only what was measured")
end

do
    local w = PW.new()
    for _ = 1, 4 do PW.observe(w, 0x40, 660) end
    for _ = 1, 2 do PW.observe(w, 0x40, 661) end
    local r = PW.report(w).rows[1]
    t.eq(#r.action_ids, 2, "every action seen with a mask is kept")
    t.eq(r.action_ids[1].action_id, 660, "most-seen first")
    t.eq(r.action_ids[1].ticks, 4, "with its count")
    t.eq(r.top_action_id, 660, "and the top one is named")
end

t.eq(PW.report(nil), nil, "a report of nothing is nothing")

return t.finish()
