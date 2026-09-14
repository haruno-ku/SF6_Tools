-- Unit tests for func/ComboExplorer/core/DamageScaling.lua
--
-- The model is from public write-ups and unverified on this build, so what is
-- tested is that it does what those write-ups say, exactly - the sequence, the
-- floor, the starter rule, the rush, the SA minimum and the SP reduction - and
-- that it refuses to produce a total when a move has no figure.

local t = require("tests.lua.harness")
local DS = require("func/ComboExplorer/core/DamageScaling")

local function near(a, b, msg)
    if type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-9 then
        return t.ok(true, msg)
    end
    return t.eq(a, b, msg)
end

local LIGHT = "\229\188\177"   -- 弱
local MED = "\228\184\173"     -- 中
local HEAVY = "\229\188\186"   -- 强

local function mv(notation, over)
    local s = { notation = notation, category = "normal", input_method = "manual" }
    for k, v in pairs(over or {}) do s[k] = v end
    return s
end
local DRC = { kind = "drive_rush_cancel" }

-- Numbers the steps as a route does, and builds one fact per move.
local function route(list, damages, gains)
    local steps, facts = {}, {}
    for i, s in ipairs(list) do
        local c = {}
        for k, v in pairs(s) do c[k] = v end
        c.index = i
        steps[i] = c
        if c.kind == nil then
            local m = #facts + 1
            facts[m] = { predicted_damage = damages and damages[m], super_gain = gains and gains[m] }
        end
    end
    return steps, facts
end

local function near_list(actual, expected, msg)
    local same = type(actual) == "table" and #actual == #expected
    for i = 1, #expected do
        if not same then break end
        if math.abs(actual[i] - expected[i]) >= 1e-9 then same = false end
    end
    if same then return t.ok(true, msg) end
    return t.eq_list(actual, expected, msg)
end

local function factors(res)
    local out = {}
    for i, s in ipairs(res.steps) do out[i] = s.factor end
    return out
end

-- --- the model's own description ---------------------------------------------

t.group("the model says what it is")

local m = DS.model()
t.eq(m.id, "sf6-public-scaling-v1", "it has an id")
t.eq(m.verified, false, "and says nobody has checked it on this build")
t.ok(#m.source >= 1 and m.source[1]:find("note.com", 1, true) ~= nil, "and where it came from")
t.ok(#m.not_modelled >= 5, "and what it leaves out")
local joined = table.concat(m.not_modelled, " | ")
t.ok(joined:find("counter", 1, true) ~= nil, "counter hits among them")
t.ok(joined:find("AUTO", 1, true) ~= nil, "Modern assist input among them")
t.ok(joined:find("rounding", 1, true) ~= nil, "and rounding")
m.not_modelled[1] = "scribbled"
t.ok(DS.model().not_modelled[1] ~= "scribbled", "a caller editing its copy does not edit the model")

-- --- the reduction sequence --------------------------------------------------

t.group("reduction per move")

local seq = {}
for k = 1, 12 do seq[k] = 100 - DS.reduction(k, false) end
t.eq_list(seq, { 100, 100, 80, 70, 60, 50, 40, 30, 20, 10, 10, 10 },
          "100, 100, 80, 70 ... down to the 10% floor and no further")

local lseq = {}
for k = 1, 11 do lseq[k] = 100 - DS.reduction(k, true) end
t.eq_list(lseq, { 100, 80, 70, 60, 50, 40, 30, 20, 10, 10, 10 },
          "a light starter: 100, 80, 70 - the normal starter +10 is not added on top")

t.eq(DS.reduction(2, true, { light_starter_reduction = 30 }), 30,
     "the light starter value is a parameter")
t.eq(DS.reduction(20, false, { max_total_reduction = 95 }), 95, "and so is the cap")
t.eq(DS.PARAMS.max_total_reduction, 90, "and an override does not change the defaults")

-- --- the factor --------------------------------------------------------------

t.group("one move's factor, and the order it is built in")

near(DS.factor(0, false, false, nil), 1, "nothing applies: 1")
near(DS.factor(20, true, false, nil), 0.8 * 0.85, "after a rush: x0.85")
near(DS.factor(0, false, true, nil), 0.8, "an SP move: x0.8")
near(DS.factor(20, true, true, nil), 0.8 * 0.85 * 0.8, "both multiply")

local f, g = DS.factor(80, false, false, 1)
near(f, 0.30, "SA1 at 20% is lifted to its 30% minimum")
t.eq(g, true, "and says the minimum was applied")
near(DS.factor(80, false, false, 2), 0.40, "SA2's minimum is 40%")
near(DS.factor(80, false, false, 3), 0.50, "SA3's minimum is 50%")
f, g = DS.factor(20, false, false, 3)
near(f, 0.80, "an SA above its minimum keeps its own factor")
t.eq(g, false, "and the minimum is not said to apply")
-- The note replaces the FINAL correction, which already includes DR and
-- Modern, so the minimum comes last: 0.5 stays 0.5 through the SP reduction.
near(DS.factor(80, true, true, 3), 0.50,
     "the minimum is applied after the rush and SP multipliers, not before")
near(DS.factor(40, false, true, 3), 0.50,
     "an SP super at 60% x0.8 = 48% is lifted to 50%")
near(DS.factor(80, false, false, nil), 0.20, "a move with no SA level gets no minimum")

t.eq(DS.sa_level(-10000), 1, "super cost -10000 is level 1")
t.eq(DS.sa_level(-20000), 2, "-20000 is level 2")
t.eq(DS.sa_level(-30000), 3, "-30000 is level 3 (and a Critical Art)")
t.is_nil(DS.sa_level(300), "a positive gain is not a super")
t.is_nil(DS.sa_level(nil), "and no figure is no level")

-- --- light normals -----------------------------------------------------------

t.group("what counts as a light normal")

t.eq(DS.is_light_normal(mv(LIGHT)), true, "弱 on a normal")
t.eq(DS.is_light_normal(mv("2 + " .. LIGHT)), true, "2 + 弱 on a normal")
t.eq(DS.is_light_normal(mv(LIGHT, { category = "command_normal" })), true, "弱 on a command normal")
t.eq(DS.is_light_normal(mv(MED)), false, "中 is not")
t.eq(DS.is_light_normal(mv(LIGHT, { category = "special" })), false, "a special on 弱 is not a normal")
t.eq(DS.is_light_normal(mv("SP")), false, "SP is not")
t.eq(DS.is_light_normal({ category = "normal", classic = "2+LK" }), true,
     "with no Modern notation, classic LK counts")
t.eq(DS.is_light_normal({ category = "normal", classic = "5LP" }), true, "and LP")
t.eq(DS.is_light_normal({ category = "normal", classic = "5MP" }), false, "MP does not")
t.eq(DS.is_light_normal(nil), false, "nothing is not a light normal")

-- --- whole routes ------------------------------------------------------------

t.group("a whole route")

do
    local steps, facts = route({ mv(HEAVY), mv(HEAVY), mv(HEAVY), mv(HEAVY) },
                               { 1000, 1000, 1000, 1000 })
    local r = DS.scale_route(steps, facts)
    near_list(factors(r), { 1, 1, 0.8, 0.7 }, "a heavy starter: 100, 100, 80, 70")
    near(r.total, 3500, "and the total is the sum of damage x factor, unrounded")
    t.eq(r.light_starter, false, "not a light starter")
    t.eq(r.steps[3].stage, 3, "each move carries its stage")
    t.eq(r.steps[3].damage, 1000, "and its damage")
end

do
    local steps, facts = route({ mv(LIGHT), mv(LIGHT), mv(HEAVY) }, { 400, 400, 1000 })
    local r = DS.scale_route(steps, facts)
    t.eq(r.light_starter, true, "a 弱 first move is a light starter")
    near_list(factors(r), { 1, 0.8, 0.7 }, "100, 80, 70")
    near(r.total, 400 + 320 + 700, "total 1420")
end

do
    -- 12 moves reaches the floor.
    local list, dmg = {}, {}
    for i = 1, 12 do list[i] = mv(HEAVY) dmg[i] = 1000 end
    local r = DS.scale_route(route(list, dmg))
    near(r.steps[12].factor, 0.1, "a long route floors at 10%")
    near(r.steps[11].factor, 0.1, "and stays there")
end

do
    -- H > DRC > H > H > DRC > H
    local steps, facts = route({ mv(HEAVY), DRC, mv(HEAVY), mv(HEAVY), DRC, mv(HEAVY) },
                               { 1000, 1000, 1000, 1000 })
    local r = DS.scale_route(steps, facts)
    t.eq(#r.steps, 4, "a rush is not a move: four stages from six steps")
    t.eq(r.steps[2].stage, 2, "the move after the rush is stage 2, not 3")
    t.eq(r.steps[2].step_index, 3, "and says which step it is")
    t.eq(r.steps[1].drive_rush, false, "the move before the rush is not scaled by it")
    near(r.steps[2].factor, 0.85, "the move after it is x0.85")
    near(r.steps[3].factor, 0.8 * 0.85, "and so is every move after that")
    near(r.steps[4].factor, 0.7 * 0.85, "a second rush does not stack")
    t.eq(r.drive_rush_from_stage, 2, "the rush is reported from the stage it first applies to")
end

do
    local steps, facts = route({ mv(HEAVY), mv(HEAVY, { input_method = "simple", notation = "SP" }) },
                               { 1000, 1000 })
    local r = DS.scale_route(steps, facts)
    near(r.steps[2].factor, 0.8, "a simple (SP) move deals 80%")
    t.eq(r.steps[2].simple_input, true, "and says why")
    local steps2, facts2 = route({ mv(HEAVY), mv("AUTO + " .. HEAVY, { input_method = "assist" }) },
                                 { 1000, 1000 })
    near(DS.scale_route(steps2, facts2).steps[2].factor, 1, "an assist (AUTO) move is not reduced")
end

do
    local sa = mv("720 + " .. HEAVY, { category = "super" })
    local list, dmg, gains = {}, {}, {}
    for i = 1, 8 do list[i] = mv(HEAVY) dmg[i] = 1000 end
    list[9], dmg[9], gains[9] = sa, 4800, -30000
    local r = DS.scale_route(route(list, dmg, gains))
    t.eq(r.steps[9].sa_level, 3, "the super's level is read from its cost")
    near(r.steps[9].factor, 0.5, "and a 9th-move SA3 is lifted from 20% to 50%")
    t.eq(r.steps[9].sa_minimum_applied, true, "saying so")

    local unknown = mv("720 + " .. HEAVY, { category = "super" })
    local r2 = DS.scale_route(route({ mv(HEAVY), mv(HEAVY), unknown }, { 1000, 1000, 4800 }))
    near(r2.steps[3].factor, 0.8, "a super with no known level gets no minimum")
    t.eq(r2.sa_level_unknown_steps, 1, "and is counted")
end

do
    local steps, facts = route({ mv(HEAVY), mv(HEAVY), mv(HEAVY) }, { 1000, nil, 1000 })
    local r = DS.scale_route(steps, facts)
    t.is_nil(r.total, "one move with no damage figure and there is no total")
    t.eq(r.missing_damage_steps, 1, "the gap is counted")
    t.eq(r.steps[2].stage, 2, "the move still takes its stage")
    near(r.steps[3].factor, 0.8, "so the move after it is still scaled as the 3rd")
    t.is_nil(DS.scale_route({}, {}).total, "and an empty route has no total")
end

do
    local steps, facts = route({ mv(HEAVY), mv(HEAVY), mv(HEAVY) }, { 1000, 1000, 1000 })
    local r = DS.scale_route(steps, facts, { drive_rush_multiplier = 0.5,
                                             combo_reduction_per_stage = 0,
                                             normal_starter_reduction = 0 })
    near(r.total, 3000, "parameters reach a whole route")
end

return t.finish()
