-- Unit tests for func/ComboExplorer/core/TestContext.lua
--
-- This module exists because a field that had been on every record since the
-- beginning was never once set, so the things worth pinning are the ways it
-- could go back to being useless:
--
--   writing "midscreen" when nothing controlled the positions
--   writing "normal" when nobody observed whether the hit countered
--   letting a record with no conditions join a cohort that has them
--   deciding two cohorts are the same from the hash instead of the string

local t = require("tests.lua.harness")
local TC = require("func/ComboExplorer/core/TestContext")

-- What StageControl.DEFAULTS actually ships: nothing controlled, nothing pinned.
local SHIPPED = { target_positions = false, pin = false, position_tolerance = 0.5 }

-- --- it will not invent an experiment ------------------------------------------

t.group("uncontrolled is recorded as uncontrolled")

do
    local ctx, why = TC.of({ stage = SHIPPED })
    t.ok(ctx ~= nil, "the shipped stage config produces a record: " .. tostring(why))
    t.eq(ctx.positions.controlled, false,
         "positions are NOT controlled, because target_positions is off")
    t.eq(ctx.resources.pinned, false, "and the gauges are not pinned")
    t.ok(tostring(ctx.positions.reason):find("target_positions") ~= nil,
         "and it says why: " .. tostring(ctx.positions.reason))

    -- The two that would be easiest to write and would be inventions.
    t.is_nil(ctx.positions.p1_x, "no position is recorded, because none was set")
    t.eq(ctx.screen_position, TC.SCREEN.UNKNOWN,
         "and the stage position is unknown, not midscreen")
end

do
    local ctx = TC.of({ stage = SHIPPED })
    t.eq(ctx.counter_state, TC.COUNTER.UNKNOWN,
         "counter state starts unknown - nothing in the runtime reads it yet")
    t.ok(ctx.counter_state ~= TC.COUNTER.NORMAL,
         "and unknown is not normal: normal would be an answer nobody measured")
end

do
    local ctx = TC.of({ stage = SHIPPED })
    t.eq(ctx.opponent.known, false, "with no opponent given, that is said out loud")
    t.is_nil(ctx.opponent.character, "rather than left as a nil somebody has to interpret")

    local named = TC.of({ stage = SHIPPED, opponent = { character = "Zangief" } })
    t.eq(named.opponent.known, true, "and a named opponent is known")
    t.eq(named.opponent.character, "Zangief", "by name")
end

-- --- it refuses rather than defaults --------------------------------------------

t.group("what it will not guess")

do
    local nope, why = TC.of({})
    t.is_nil(nope, "no stage configuration, no conditions record")
    t.ok(tostring(why):find("no stage configuration") ~= nil, tostring(why))

    -- nil is not false. `false` is the shipped value and means "known: off";
    -- a config that never mentioned positions has said nothing at all, and
    -- reading that as off would be the same invention from a different angle.
    local absent, awhy = TC.of({ stage = { pin = false } })
    t.is_nil(absent, "a stage config that never mentions target_positions is refused")
    t.ok(tostring(awhy):find("unknown is not the same as off") ~= nil, tostring(awhy))

    local nopin, pwhy = TC.of({ stage = { target_positions = false } })
    t.is_nil(nopin, "and the same for pin")
    t.ok(tostring(pwhy):find("stage.pin") ~= nil, tostring(pwhy))

    local bad, bwhy = TC.of({ stage = SHIPPED, counter_state = "probably" })
    t.is_nil(bad, "a counter state outside the vocabulary is refused")
    t.ok(tostring(bwhy):find("not one of") ~= nil, tostring(bwhy))

    local bads, bswhy = TC.of({ stage = SHIPPED, screen_position = "middle-ish" })
    t.is_nil(bads, "and so is a screen position outside it")
    t.ok(tostring(bswhy):find("not one of") ~= nil, tostring(bswhy))
end

-- --- controlled conditions carry their values -------------------------------------

t.group("when something IS controlled, the values travel")

do
    local ctx, why = TC.of({
        stage = { target_positions = { p1 = -150, p2 = 150 },
                  position_tolerance = 0.5,
                  pin = { attacker_hp = 10000, victim_hp = 10000,
                          attacker_drive = 6, attacker_super = 3 } },
    })
    t.ok(ctx ~= nil, "a controlled setup produces a record: " .. tostring(why))
    t.eq(ctx.positions.controlled, true, "positions are controlled")
    t.eq(ctx.positions.p1_x, -150, "and both targets are on the record")
    t.eq(ctx.positions.p2_x, 150, "so a later reader does not have to find the config")
    t.eq(ctx.positions.tolerance, 0.5, "with the tolerance they were held to")
    t.eq(ctx.resources.pinned, true, "the gauges are pinned")
    t.eq(ctx.resources.attacker_super, 3, "at the values that were pinned")

    -- Still unknown. Knowing x = -150 is not knowing where that is on a stage
    -- whose width nobody has measured.
    t.eq(ctx.screen_position, TC.SCREEN.UNKNOWN,
         "and the stage position is STILL unknown: an x is not a place")
end

-- --- the canonical string is the identity -------------------------------------------

t.group("two conditions are the same when their canonical strings are")

do
    local a = TC.of({ stage = SHIPPED })
    local b = TC.of({ stage = SHIPPED })
    t.eq(a.canonical, b.canonical, "the same inputs produce the same string")
    t.eq(TC.same(a, b), true, "so they are the same cohort")

    local counter = TC.of({ stage = SHIPPED, counter_state = TC.COUNTER.COUNTER })
    t.ok(a.canonical ~= counter.canonical,
         "a counter hit is a different experiment, and the string says so")
    t.eq(TC.same(a, counter), false, "so it is a different cohort")

    local pinned = TC.of({ stage = { target_positions = false,
                                     pin = { attacker_super = 3 } } })
    t.eq(TC.same(a, pinned), false, "pinning the gauges changes the cohort too")

    local opp = TC.of({ stage = SHIPPED, opponent = { character = "Ryu" } })
    t.eq(TC.same(a, opp), false, "and so does who was standing there")
end

do
    -- Every field the record carries has to reach the string, or two different
    -- experiments would share an identity.
    local base = TC.of({ stage = SHIPPED })
    local seen = {}
    for _, variant in ipairs({
        TC.of({ stage = SHIPPED, counter_state = TC.COUNTER.PUNISH }),
        TC.of({ stage = SHIPPED, screen_position = TC.SCREEN.CORNER }),
        TC.of({ stage = SHIPPED, opponent = { character = "Ken" } }),
        TC.of({ stage = { target_positions = { p1 = -150, p2 = 150 },
                          position_tolerance = 0.5, pin = false } }),
        TC.of({ stage = { target_positions = false, pin = { victim_hp = 1 } } }),
    }) do
        t.ok(variant.canonical ~= base.canonical,
             "distinct from the baseline: " .. variant.canonical)
        t.is_nil(seen[variant.canonical],
                 "and distinct from every other variant: " .. variant.canonical)
        seen[variant.canonical] = true
    end
end

do
    -- Formatting is the build's business and must not be. A canonical string
    -- that renders 150 as "150" here and "150.0" elsewhere would split one
    -- cohort in two across machines.
    local int = TC.of({ stage = { target_positions = { p1 = -150, p2 = 150 },
                                  position_tolerance = 0.5, pin = false } })
    local float = TC.of({ stage = { target_positions = { p1 = -150.0, p2 = 150.0 },
                                    position_tolerance = 0.5, pin = false } })
    t.eq(int.canonical, float.canonical,
         "150 and 150.0 are the same position, and the string agrees")
end

-- --- the hash is an index, not the identity --------------------------------------------

t.group("the hash never decides anything")

do
    local a = TC.of({ stage = SHIPPED })
    t.ok(type(a.context_hash) == "string", "a hash is produced for the database column")
    t.ok(a.context_hash:find("^fnv1a64:") ~= nil, "named so it can be recognised later")
    t.eq(a.context_hash, TC.hash(a.canonical), "and it is a function of the string")

    -- If two records carried the same hash and different strings, same() has to
    -- say they are different: a collision must not merge two cohorts.
    local forged_a = { canonical = "positions=uncontrolled;A", context_hash = "fnv1a64:dead" }
    local forged_b = { canonical = "positions=uncontrolled;B", context_hash = "fnv1a64:dead" }
    t.eq(TC.same(forged_a, forged_b), false,
         "so an identical hash over different conditions is still two cohorts")

    t.is_nil(TC.hash(nil), "nothing to hash, no hash")
end

-- --- records with no conditions at all ---------------------------------------------------

t.group("a record written before conditions existed")

do
    t.eq(TC.key(nil), TC.UNRECORDED, "has its own key")
    t.eq(TC.key({}), TC.UNRECORDED, "and so does one whose conditions will not canonicalise")

    local ctx = TC.of({ stage = SHIPPED })
    t.eq(TC.key(ctx), ctx.canonical, "while a real one keys on its canonical string")
    t.ok(TC.key(ctx) ~= TC.UNRECORDED,
         "so the old lines never join a cohort that knows its conditions")

    -- Two records that both know nothing are not thereby the same experiment.
    t.eq(TC.same({}, {}), false, "and unknown does not equal unknown")
end

-- --- canonical() on a hand-built record ----------------------------------------------------

t.group("canonical() checks what it is given")

do
    local ok = TC.canonical({ positions = { controlled = false },
                              resources = { pinned = false },
                              counter_state = TC.COUNTER.UNKNOWN,
                              screen_position = TC.SCREEN.UNKNOWN,
                              opponent = {} })
    t.ok(type(ok) == "string", "a complete record canonicalises")

    local nope, why = TC.canonical({ resources = { pinned = false } })
    t.is_nil(nope, "one with no positions block does not")
    t.ok(tostring(why):find("positions") ~= nil, tostring(why))

    -- nil is neither true nor false, and reading it as either would be the
    -- invention this module exists to prevent.
    local vague, vwhy = TC.canonical({ positions = { controlled = nil },
                                       resources = { pinned = false },
                                       counter_state = TC.COUNTER.UNKNOWN,
                                       screen_position = TC.SCREEN.UNKNOWN,
                                       opponent = {} })
    t.is_nil(vague, "and neither does one that never says whether positions were controlled")
    t.ok(tostring(vwhy):find("neither true nor false") ~= nil, tostring(vwhy))
end

do
    -- A character name carrying one of the separators must not add a field.
    --
    -- Today the opponent is the LAST field, so an injected separator cannot
    -- make two different cohorts collide - it can only produce a string with a
    -- duplicate-looking field in it. The guarantee worth pinning is therefore
    -- the shape: whatever anybody is called, the string is the same five
    -- fields, so a reader that splits on ; and = gets the same answer.
    local plain = TC.of({ stage = SHIPPED, opponent = { character = "Ken" } })
    local sneaky = TC.of({ stage = SHIPPED, opponent = { character = "A;counter=counter" } })

    local function fields(s)
        local n = 0
        for _ in s:gmatch("[^;]+") do n = n + 1 end
        return n
    end
    local function occurrences(s, needle)
        local n = 0
        for _ in s:gmatch(needle) do n = n + 1 end
        return n
    end

    t.eq(fields(sneaky.canonical), fields(plain.canonical),
         "a name full of separators produces the same number of fields: "
         .. sneaky.canonical)
    t.eq(occurrences(sneaky.canonical, "counter="), 1,
         "with exactly one counter= in it, not two")
    t.ok(sneaky.canonical ~= plain.canonical,
         "while still being a different opponent from Ken")
end

return t.finish()
