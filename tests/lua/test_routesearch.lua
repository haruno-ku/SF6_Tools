-- Unit tests for func/ComboExplorer/core/RouteSearch.lua
--
-- The route record produced here is the one the runner will consume and the one
-- a confirmed combo is written against. There is no separate offline shape, so
-- these tests check the record as a contract: every route leaves theoretical,
-- every step's delay stays nil, and every step names the edge it came in on.
--
-- The limits are the other half. Each of them bounds the SEARCH and none of
-- them is a claim about the game, so a route that a limit dropped has to be
-- counted rather than silently absent - a cap that truncates quietly reads as
-- "this was everything".

local t = require("tests.lua.harness")
local RS = require("func/ComboExplorer/core/RouteSearch")
local GraphStore = require("func/ComboExplorer/core/GraphStore")
local CG = require("func/ComboExplorer/core/CandidateGenerator")
local Catalog = require("func/ComboExplorer/core/Catalog")
local FrameData = require("func/ComboExplorer/core/FrameData")
local Schema = require("func/ComboExplorer/core/Schema")

local cat = Catalog.build(dofile("tests/lua/fixtures/zangief_catalog.lua"))
local idx = FrameData.index(dofile("tests/lua/fixtures/zangief_framedata.lua"))

local IDENTITY = { character = "zangief", game_patch = "2026-08-03",
                   ac_sha256 = "aaaa", bcm_sha256 = "bbbb" }

local gen = CG.generate(cat, idx, {
    from = { categories = { "normal", "command_normal" }, input_methods = { "manual" } },
    to = { categories = { "normal", "command_normal", "special", "od_special", "super" },
           input_methods = { "manual" } },
    include_followups = true,
})
local g = GraphStore.build(gen.candidates, IDENTITY)

local SETUP = {
    frame_idx = idx,
    character = "zangief", control_scheme = "modern",
    position = "midscreen", counter = "none",
}

local function search(extra)
    local o = {}
    for k, v in pairs(SETUP) do o[k] = v end
    for k, v in pairs(extra or {}) do o[k] = v end
    return RS.search(g, o)
end

-- --- the record is the contract ----------------------------------------------

t.group("the route record")

local r = search({ max_steps = 3, beam_width = 4000, max_routes = 20000 })
t.ok(r ~= nil and #r.routes > 0, "routes are found (" .. #r.routes .. ")")

local bad, first_problem = 0, nil
for _, route in ipairs(r.routes) do
    local ok, problems = Schema.validate(Schema.KIND.ROUTE, route)
    if not ok then bad = bad + 1 first_problem = first_problem or problems[1] end
end
t.eq(bad, 0, "every route validates as ce.route.v1"
     .. (first_problem and (" (" .. first_problem.field .. ": " .. first_problem.problem .. ")") or ""))

-- Counted rather than asserted per route: a few thousand identical passing
-- lines hide the one that matters.
local not_theoretical, claims_run = 0, 0
for _, route in ipairs(r.routes) do
    if route.status ~= "theoretical" then not_theoretical = not_theoretical + 1 end
    if route.runtime_verified ~= false then claims_run = claims_run + 1 end
end
t.eq(not_theoretical, 0, "every route leaves theoretical")
t.eq(claims_run, 0, "and not one of them claims to have been run")

-- The whole reason there is one route representation instead of two: the delay
-- between two moves is what the sweep measures, and a frame-table subtraction
-- dressed up as a delay would look measured.
local fabricated = 0
for _, route in ipairs(r.routes) do
    for _, s in ipairs(route.steps) do
        if s.delay_ticks ~= nil then fabricated = fabricated + 1 end
    end
end
t.eq(fabricated, 0, "no step carries an invented delay")

local sample = r.routes[1]
t.is_nil(sample.steps[1].via_edge, "the first step is entered from neutral, so has no edge")
local unlinked, dangling = 0, 0
for _, route in ipairs(r.routes) do
    for i = 2, #route.steps do
        if route.steps[i].via_edge == nil then unlinked = unlinked + 1
        elseif GraphStore.edge(g, route.steps[i].via_edge) == nil then dangling = dangling + 1 end
    end
end
t.eq(unlinked, 0, "every step after the first names the edge it came in on")
t.eq(dangling, 0, "and every one of those edges is in the graph")
t.eq(#sample.edge_ids, #sample.steps - 1, "an n-step route has n-1 edges")
t.eq(sample.character, "zangief", "the setup travels with the route")
t.eq(sample.position, "midscreen", "including the position it is only true for")

-- Offline predictions live under `basis`, never under a measured-sounding name.
t.ok(sample.basis.predicted_damage_sum ~= nil, "a predicted damage sum is carried")
t.is_nil(sample.offline_score, "but no score - that is Scoring's job, not the search's")
t.ok(sample.basis.steps_with_missing_data ~= nil, "and the gaps are counted")

-- --- limits bound the search, and say what they dropped ----------------------

t.group("max_steps")

for _, n in ipairs({ 2, 3, 4 }) do
    local rr = search({ max_steps = n, beam_width = 4000, max_routes = 20000 })
    local longest, shortest = 0, 99
    for _, route in ipairs(rr.routes) do
        longest = math.max(longest, route.length)
        shortest = math.min(shortest, route.length)
    end
    t.eq(longest, n, ("max_steps %d is respected"):format(n))
    t.ok(shortest >= 2, "and a single move is never a route")
end

t.group("repeat limits")

local rep = search({ max_steps = 4, max_repeat_per_action = 1, beam_width = 4000,
                     max_routes = 20000 })
local repeated = 0
for _, route in ipairs(rep.routes) do
    local seen = {}
    for _, s in ipairs(route.steps) do
        if seen[s.action_id] then repeated = repeated + 1 end
        seen[s.action_id] = true
    end
end
t.eq(repeated, 0, "under a limit of one, no route uses an action twice")
t.ok(rep.stats.pruned.max_repeat_per_action ~= nil,
     "and the drops are counted rather than silently absent")

local consec = search({ max_steps = 4, max_repeat_per_action = 4,
                        max_consecutive_repeat = 1, beam_width = 4000, max_routes = 20000 })
local back_to_back = 0
for _, route in ipairs(consec.routes) do
    for i = 2, #route.steps do
        if route.steps[i].action_id == route.steps[i - 1].action_id then
            back_to_back = back_to_back + 1
        end
    end
end
t.eq(back_to_back, 0, "with a consecutive limit of one, no move appears twice in a row")

-- --- loop detection ----------------------------------------------------------

t.group("loop detection")

-- Two moves that each link into the other. Without an edge bound this walks
-- forever; the point of the test is that it terminates and says why.
local function cyc_edge(a, b)
    return Schema.new(Schema.KIND.EDGE, {
        id = ("%d:manual->%d:manual"):format(a, b),
        from = { action_id = a, input_method = "manual", notation = "A" .. a,
                 classic = "LP", category = "normal", canonical_status = "verified" },
        to   = { action_id = b, input_method = "manual", notation = "A" .. b,
                 classic = "LP", category = "normal", canonical_status = "verified" },
        reasons = { "chain_cancel" },
        confidence = "medium",
        requires_runtime_validation = { "actual_input_timing" },
        unknown_detail = { actual_input_timing = "the sweep measures it" },
        provenance = Schema.provenance({}),
    })
end
local cyc = GraphStore.build({ cyc_edge(1, 2), cyc_edge(2, 1) }, IDENTITY)

local looped = RS.search(cyc, { max_steps = 8, max_repeat_per_action = 9,
                                max_consecutive_repeat = 9 })
t.ok(looped ~= nil, "a cyclic graph searches")
local longest = 0
for _, route in ipairs(looped.routes) do longest = math.max(longest, route.length) end
t.eq(longest, 3, "the edge bound stops A>B>A>B: three steps is as far as it goes")
t.ok(looped.stats.pruned.max_repeat_per_edge ~= nil, "and the cycle is counted as a drop")

-- Raise the edge bound and the step limit becomes the thing that stops it -
-- which is the point: a bound, not a verdict.
local deeper = RS.search(cyc, { max_steps = 5, max_repeat_per_edge = 9,
                                max_repeat_per_action = 9, max_consecutive_repeat = 9 })
local deepest = 0
for _, route in ipairs(deeper.routes) do deepest = math.max(deepest, route.length) end
t.eq(deepest, 5, "with the edge bound raised, max_steps is what stops the walk")

-- --- resource budgets --------------------------------------------------------

t.group("resource budgets")

local one_super = search({ max_steps = 4, beam_width = 4000, max_routes = 20000 })
local over_super = 0
for _, route in ipairs(one_super.routes) do
    if route.basis.super_steps > 1 then over_super = over_super + 1 end
end
t.eq(over_super, 0, "the default budget of one super is never exceeded")

local no_super = search({ max_steps = 3, max_super_steps = 0, beam_width = 4000,
                          max_routes = 20000 })
local any_super = 0
for _, route in ipairs(no_super.routes) do
    if route.basis.super_steps ~= 0 then any_super = any_super + 1 end
end
t.eq(any_super, 0, "with a zero super budget, no route uses one")
t.ok(no_super.stats.pruned.max_super_steps ~= nil, "and the budget records what it dropped")
t.ok(#no_super.routes > 0, "while plenty of routes survive without one")

-- A budget cannot judge a move the source has no numbers for, and must not
-- delete it on a number nobody has. Searching with no frame data at all is the
-- extreme case of that.
local blind = RS.search(g, { character = "zangief", max_steps = 3,
                             beam_width = 4000, max_routes = 20000 })
t.ok(#blind.routes > 0, "routes are found with no frame data at all (" .. #blind.routes .. ")")
local unknown_counted, claimed_damage = false, 0
for _, route in ipairs(blind.routes) do
    if route.basis.steps_with_missing_data == route.length then unknown_counted = true end
    if route.basis.damage_known_steps ~= 0 then claimed_damage = claimed_damage + 1 end
end
t.eq(claimed_damage, 0, "and nothing claims a damage figure it does not have")
t.ok(unknown_counted, "the missing data is counted on the route rather than assumed away")

-- --- no silent caps ----------------------------------------------------------

t.group("caps are reported")

local narrow = search({ max_steps = 3, beam_width = 5, max_routes = 20000 })
t.ok(narrow.stats.beam_dropped_total > 0, "a narrow beam drops partial routes")
t.eq(narrow.stats.complete, false, "and the result says it is not the whole space")

local capped = search({ max_steps = 3, beam_width = 4000, max_routes = 10 })
t.eq(#capped.routes, 10, "max_routes caps the output")
t.ok(capped.stats.truncated_routes > 0, "and the routes it did not emit are counted")
t.eq(capped.stats.complete, false, "so the result is not mistaken for the whole space")

t.eq(r.stats.complete, true, "an unconstrained run reports itself complete")

-- --- determinism -------------------------------------------------------------

t.group("determinism")

local a1 = search({ max_steps = 3, beam_width = 50, max_routes = 40 })
local a2 = search({ max_steps = 3, beam_width = 50, max_routes = 40 })
local same = (#a1.routes == #a2.routes)
if same then
    for i = 1, #a1.routes do
        if a1.routes[i].id ~= a2.routes[i].id then same = false break end
    end
end
t.ok(same, "the same graph and the same limits produce the same routes in the same order")

-- --- canonical variants ------------------------------------------------------

t.group("canonical variants")

-- 601 and 602 are both "弱"; the catalog cannot say which id the button
-- produces, so the graph holds both and the search walks both. Two routes that
-- differ only there are the same buttons in the same order.
local collapsed = search({ max_steps = 3, beam_width = 4000, max_routes = 20000,
                           collapse_canonical_variants = true })
t.ok(#collapsed.routes < #r.routes,
     ("collapsing folds variants together (%d -> %d)"):format(#r.routes, #collapsed.routes))
t.ok(collapsed.stats.collapsed_variants > 0,
     "and says how many it folded (" .. collapsed.stats.collapsed_variants .. ")")

local folded
for _, route in ipairs(collapsed.routes) do
    if (route.canonical_variants or 1) > 1 then folded = route break end
end
t.ok(folded ~= nil, "a folded route exists")
t.ok(#folded.variant_route_ids > 0, "and keeps the ids it stands for, rather than losing them")

local shapes, dupes = {}, 0
for _, route in ipairs(collapsed.routes) do
    if shapes[route.shape_key] then dupes = dupes + 1 end
    shapes[route.shape_key] = true
end
t.eq(dupes, 0, "each button sequence appears exactly once")

-- Off by default, because the distinction is real and the runtime resolves it.
t.eq(RS.DEFAULTS.collapse_canonical_variants, false, "collapsing is not the default")

-- --- degenerate input --------------------------------------------------------

t.group("degenerate input")

t.is_nil(RS.search(nil, {}), "no graph is refused")
t.is_nil(RS.search({}, {}), "a table that is not a graph is refused")

local empty = RS.search(GraphStore.new(IDENTITY), {})
t.eq(#empty.routes, 0, "an empty graph yields no routes")
t.eq(empty.stats.starts, 0, "and no starts")

return t.finish()
