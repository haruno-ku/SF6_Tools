-- Unit tests for func/ComboExplorer/core/Scoring.lua
--
-- Most of what is being tested here is what the score does NOT contain. An
-- offline score that carries a damage figure, a window width or a difficulty
-- number would be read as measurement by everything downstream, and the whole
-- point of the split is that those three come from the game or not at all.
--
-- The rest is ordering. There is no single best route, so the axes are checked
-- separately and the Pareto frontier is checked for the property that defines
-- it rather than for a particular membership.

local t = require("tests.lua.harness")
local Scoring = require("func/ComboExplorer/core/Scoring")
local RS = require("func/ComboExplorer/core/RouteSearch")
local GraphStore = require("func/ComboExplorer/core/GraphStore")
local CG = require("func/ComboExplorer/core/CandidateGenerator")
local Catalog = require("func/ComboExplorer/core/Catalog")
local FrameData = require("func/ComboExplorer/core/FrameData")
local Schema = require("func/ComboExplorer/core/Schema")

local cat = Catalog.build(dofile("tests/lua/fixtures/zangief_catalog.lua"))
local idx = FrameData.index(dofile("data/frame-data/zangief.lua"))

local gen = CG.generate(cat, idx, {
    from = { categories = { "normal", "command_normal" }, input_methods = { "manual" } },
    to = { categories = { "normal", "command_normal", "special", "od_special", "super" },
           input_methods = { "manual", "simple" } },
    include_followups = true,
})
local g = GraphStore.build(gen.candidates, {
    character = "zangief", game_patch = "2026-08-03",
    ac_sha256 = "aaaa", bcm_sha256 = "bbbb",
})
local found = RS.search(g, {
    frame_idx = idx, character = "zangief", control_scheme = "modern",
    position = "midscreen", counter = "none",
    max_steps = 3, beam_width = 4000, max_routes = 20000,
})
local routes = Scoring.apply(found.routes)

-- --- input shape -------------------------------------------------------------

t.group("counting inputs from notation")

local light = Scoring.step_inputs("\229\188\177")            -- 弱
t.eq(light.direction_inputs, 0, "a bare light has no direction")
t.eq(light.button_presses, 1, "and one button")
t.eq(light.motion_length, 0, "and no motion")

local crouch = Scoring.step_inputs("2 + \228\184\173")       -- 2 + 中
t.eq(crouch.direction_inputs, 1, "a crouching medium holds one direction")
t.eq(crouch.total, 2, "for two inputs in all")
t.eq(crouch.motion_length, 0, "a single held direction is not a motion")

-- 360 is the reason the shorthand table exists: it contains a 0, which is not a
-- numpad direction, and counting its characters would say three.
local spd = Scoring.step_inputs("360 + \229\188\186")        -- 360 + 强
t.eq(spd.direction_inputs, 7, "a 360 expands to seven directions, not three characters")
t.eq(spd.motion_length, 7, "and the whole thing is a motion")

local ca = Scoring.step_inputs("720 + \229\188\186")
t.ok(ca.direction_inputs > spd.direction_inputs, "a 720 is longer still")

local sp = Scoring.step_inputs("SP")
t.eq(sp.total, 1, "a simple special is one button")

t.is_nil(Scoring.step_inputs("RAW DR"), "a label with no input in it returns nil")
t.is_nil(Scoring.step_inputs(""), "and so does an empty string")

-- --- what the score refuses to contain ---------------------------------------

t.group("the three numbers that are not here")

t.ok(#routes > 0, "routes were scored (" .. #routes .. ")")
local s = routes[1].offline_score

t.is_nil(s.damage, "no `damage` - that name means a measured figure")
t.is_nil(s.actual_damage, "no `actual_damage`")
t.is_nil(s.execution_leniency_frames, "no window width - only a sweep can measure one")
t.is_nil(s.difficulty, "and no difficulty, which needs the window")
t.is_nil(s.advantage_frames, "no frame advantage")
t.is_nil(s.knockdown_advantage, "and no knockdown advantage")

-- Schema enforces the same thing independently, so a route carrying a score
-- still has to validate.
local bad, first = 0, nil
for _, r in ipairs(routes) do
    local ok, problems = Schema.validate(Schema.KIND.ROUTE, r)
    if not ok then bad = bad + 1 first = first or problems[1] end
end
t.eq(bad, 0, "every scored route still validates"
     .. (first and (" (" .. first.field .. ": " .. first.problem .. ")") or ""))

-- The damage sum that IS present says what it is.
t.eq(s.combo_scaling_applied, false, "the damage sum has no scaling applied")
t.ok(s.predicted_damage_known_steps ~= nil, "with the number of steps it actually knew")

-- The sum is a ceiling only when every step contributed one. A step the join
-- has no damage for contributed zero, and zero is not that move's damage, so
-- such a sum is neither a ceiling nor a floor - and must not claim to be one.
local complete_route, partial_route
for _, r in ipairs(routes) do
    if r.offline_score.predicted_damage_complete then complete_route = complete_route or r
    else partial_route = partial_route or r end
end
t.ok(complete_route ~= nil, "a route whose every step has a damage figure exists")
t.eq(complete_route.offline_score.predicted_damage_bound, "upper",
     "and its sum is an upper bound, because scaling only reduces")
t.ok(partial_route ~= nil, "so does one with a step the join could not price")
t.eq(partial_route.offline_score.predicted_damage_bound, "none",
     "and that sum claims to bound nothing in either direction")
t.ok(partial_route.offline_score.predicted_damage_bound_reason:find("neither") ~= nil,
     "with the reason stated, not just a flag")
t.is_nil(s.predicted_damage_is_upper_bound,
     "and the old unconditional flag is gone, not left alongside the honest one")

-- Drive spend is genuinely absent from the source, and is left absent.
t.is_nil(s.predicted_drive_spend, "drive spend is not invented")
t.eq(s.drive_spend_known, false, "and is marked unknown rather than zero")
t.ok(s.od_steps ~= nil, "with the OD step count standing in for it")

-- Super spend, unlike drive, is in the data - as a negative gain.
local with_super
for _, r in ipairs(routes) do
    if r.offline_score.super_steps > 0 then with_super = r break end
end
t.ok(with_super ~= nil, "a route using a super exists")
t.ok(with_super.offline_score.predicted_super_spend > 0,
     "and its super spend comes from the negative gain in the source ("
     .. tostring(with_super.offline_score.predicted_super_spend) .. ")")

-- --- execution cost is structural --------------------------------------------

t.group("execution cost")

t.eq(s.execution_cost_is_prediction, true, "execution cost says it is a prediction")
t.ok(s.execution_cost_basis ~= nil, "and shows its working")
t.ok(s.execution_cost_basis.weights ~= nil, "including the weights, which are a guess")

-- A route through a 720 has more to input than one through two normals, and the
-- cost has to reflect that or it is measuring nothing.
local plain, motion
for _, r in ipairs(routes) do
    if r.offline_score.hardest_motion == 0 and not plain then plain = r end
    if r.offline_score.hardest_motion >= 7 and not motion then motion = r end
end
t.ok(plain ~= nil and motion ~= nil, "both a motionless and a motion route exist")
t.ok(motion.offline_score.execution_cost > plain.offline_score.execution_cost,
     "a route through a big motion costs more than one without")

-- The weights are overridable, and overriding them changes the answer -
-- otherwise they would be decoration.
local reweighted = Scoring.score(motion, { weights = { motion_digit = 0 } })
t.ok(reweighted.execution_cost < motion.offline_score.execution_cost,
     "zeroing the motion weight lowers the cost")

-- --- input method mix --------------------------------------------------------

t.group("input method mix")

local mixed
for _, r in ipairs(routes) do
    if r.offline_score.simple_ratio > 0 and r.offline_score.manual_ratio > 0 then
        mixed = r break
    end
end
t.ok(mixed ~= nil, "a route mixing manual and simple inputs exists")
t.ok(mixed.offline_score.input_method_switches > 0, "and its switches are counted")
local m = mixed.offline_score
t.ok(math.abs(m.simple_ratio + m.manual_ratio + m.assist_ratio - 1) < 1e-9,
     "the three ratios cover the route exactly once")

-- --- orderings ---------------------------------------------------------------

t.group("ranking")

local by_damage = Scoring.rank(routes, Scoring.AXES.DAMAGE, 10)
t.eq(#by_damage, 10, "a limit is honoured")
local descending = true
for i = 2, #by_damage do
    if (by_damage[i - 1].offline_score.predicted_damage or 0)
        < (by_damage[i].offline_score.predicted_damage or 0) then descending = false end
end
t.ok(descending, "damage ranking is descending")

local by_simple = Scoring.rank(routes, Scoring.AXES.SIMPLICITY, 10)
t.ok(by_simple[1].offline_score.execution_cost <= by_damage[1].offline_score.execution_cost,
     "the simplest route is no harder than the most damaging one")

local by_free = Scoring.rank(routes, Scoring.AXES.RESOURCE_FREE, 5)
t.eq(by_free[1].offline_score.super_steps, 0, "the resource-free ranking leads with no super")
t.eq(by_free[1].offline_score.od_steps, 0, "and no OD")

local by_short = Scoring.rank(routes, Scoring.AXES.SHORTEST, 5)
t.eq(by_short[1].offline_score.route_length, 2, "the shortest ranking leads with two steps")

local by_conf = Scoring.rank(routes, Scoring.AXES.CONFIDENCE, 5)
t.ok(by_conf[1].min_confidence ~= "low" or routes[1].min_confidence == "low",
     "the confidence ranking leads with the best-supported reasoning available")

-- Ranking is stable: the same input gives the same order.
local again = Scoring.rank(routes, Scoring.AXES.DAMAGE, 10)
local same = true
for i = 1, 10 do if again[i].id ~= by_damage[i].id then same = false end end
t.ok(same, "and the ordering is reproducible")

-- --- pareto ------------------------------------------------------------------

t.group("pareto frontier")

local front = Scoring.pareto(routes)
t.ok(#front > 0, "a frontier exists (" .. #front .. " routes)")
t.ok(#front < #routes, "and it is smaller than the whole set")

-- The defining property: nothing in the set beats a frontier member on both
-- damage and cost at once.
local violations = 0
for _, f in ipairs(front) do
    for _, r in ipairs(routes) do
        local a, b = f.offline_score, r.offline_score
        local da, db = a.predicted_damage or 0, b.predicted_damage or 0
        if db >= da and b.execution_cost <= a.execution_cost
            and (db > da or b.execution_cost < a.execution_cost) then
            violations = violations + 1
        end
    end
end
t.eq(violations, 0, "no route dominates a frontier member on both axes")

-- The frontier comes back ordered by damage descending, so cost falls strictly
-- along it: each further entry buys less damage for less input. Any pair where
-- that is not true means one of them was dominated and should not be here.
local monotone = true
for i = 2, #front do
    if front[i].offline_score.execution_cost >= front[i - 1].offline_score.execution_cost then
        monotone = false
    end
end
t.ok(monotone, "and along the frontier, less damage always means less to input")

-- --- summary -----------------------------------------------------------------

t.group("summary")

local sum = Scoring.summary(routes)
t.eq(sum.scored, #routes, "the summary counts what it scored")
t.ok(sum.highest_predicted_damage > 0, "and names the highest predicted damage")
t.ok(sum.note:find("ordering") ~= nil, "with the caveat attached to the number itself")
t.ok(sum.by_length[2] ~= nil, "lengths are broken out")
t.ok(sum.by_confidence ~= nil, "so is confidence")

-- --- degenerate input --------------------------------------------------------

t.group("degenerate input")

t.is_nil(Scoring.score(nil), "no route is refused")
t.is_nil(Scoring.score({}), "a table with no steps is refused")
t.eq_list(Scoring.pareto({}), {}, "an empty set has an empty frontier")
t.eq_list(Scoring.rank(nil, Scoring.AXES.DAMAGE), {}, "and nothing ranks to nothing")

-- A route whose notation nobody can parse is scored, with the gap counted
-- rather than treated as an easy move.
local opaque = Scoring.score({ steps = {
    { index = 1, action_id = 1, input_method = "manual", notation = "RAW DR" },
    { index = 2, action_id = 2, input_method = "manual", notation = "RAW DR" },
} })
t.eq(opaque.steps_with_unparseable_notation, 2, "unparseable notations are counted")
t.eq(opaque.input_count, 0, "and contribute no inputs rather than a guessed number")

return t.finish()
