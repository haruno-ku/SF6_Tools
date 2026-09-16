-- Unit tests for tools/lua/practicescore.lua
--
-- practice.md ranks 31 characters on five components and people will read the
-- order as an answer. The failures worth a test are the ones that still look
-- like a finished table: a component that quietly counts a missing number as
-- zero and sends a character to the bottom, a normalisation that divides by a
-- zero spread, a tie broken by whatever order the roster happened to be in.
--
-- Everything here is hand-built tables. The module takes no io and no game.

local t = require("tests.lua.harness")
local PS = dofile("tools/lua/practicescore.lua")

local function about(actual, expected, msg, tol)
    tol = tol or 1e-9
    if type(actual) == "number" and math.abs(actual - expected) <= tol then
        return t.ok(true, msg)
    end
    return t.eq(actual, expected, msg)
end

-- --- quantile ------------------------------------------------------------------

t.group("quantile")

t.eq(PS.quantile({}, 0.25), nil, "the quantile of nothing is nil, not zero")
t.eq(PS.quantile({ 7 }, 0.25), 7, "one value is its own quantile")
t.eq(PS.quantile({ 4, 1, 3, 2 }, 0), 1, "q=0 is the minimum, and the input need not be sorted")
t.eq(PS.quantile({ 4, 1, 3, 2 }, 1), 4, "q=1 is the maximum")
about(PS.quantile({ 1, 2, 3, 4 }, 0.5), 2.5, "q=0.5 interpolates between the middle two")
about(PS.quantile({ 1, 2, 3, 4, 5 }, 0.25), 2, "q=0.25 over five values lands on the second")
t.eq(PS.quantile({ 1, "x", 3 }, 1), 3, "a non-number in the list is skipped, not counted")
t.eq(PS.quantile({ 5, 5, 5 }, 0.25), 5, "no spread means every quantile is the same value")

-- --- route summaries -----------------------------------------------------------

t.group("route_summary")

local function route(id, score)
    return { id = id, steps = {}, offline_score = score }
end

t.is_nil(PS.route_summary({ id = "r", steps = {} }),
    "a route with no offline_score has no summary - it was never scored")
t.is_nil(PS.route_summary(nil), "and nil is not a route")

local s1 = PS.route_summary(route("a", {
    execution_cost = 5.5, predicted_damage = 2000, predicted_damage_scaled = 1800,
    route_length = 2, input_count = 6, hardest_motion = 4, input_method_switches = 1,
    simple_ratio = 0.5, od_steps = 1, super_steps = 0,
    steps_with_guessed_frame_join = 1, steps_with_missing_data = 0,
    theoretical_confidence = "high",
}))
t.eq(s1.cost, 5.5, "the summary carries execution_cost")
t.eq(s1.damage_scaled, 1800, "and the scaled damage the ranking is built on")
t.eq(s1.hardest_motion, 4, "and the longest motion")
t.eq(s1.drc_steps, 0, "a score with no drive_rush_cancel_steps summarises as zero rushes")

t.eq(#PS.route_summaries({ route("a", { execution_cost = 1, route_length = 1 }),
                          { id = "b", steps = {} } }), 1,
    "route_summaries drops the unscored route instead of summarising it as empty")

t.group("top_by_damage")

local pool = {
    { id = "a", damage_scaled = 100, cost = 9 },
    { id = "b", damage_scaled = 300, cost = 4 },
    { id = "c", damage_scaled = nil, cost = 1 },
    { id = "d", damage_scaled = 200, cost = 2 },
}
local top = PS.top_by_damage(pool, 2)
t.eq(#top, 2, "top_by_damage returns the number asked for")
t.eq(top[1].id, "b", "highest scaled damage first")
t.eq(top[2].id, "d", "then the next")
t.eq(#PS.top_by_damage(pool, 10), 3,
    "the route with no scaled damage is left out, not sorted to the bottom")
t.eq(#PS.top_by_damage({}, 5), 0, "and an empty pool gives an empty top")
local tied = PS.top_by_damage({
    { id = "z", damage_scaled = 100, cost = 3 },
    { id = "y", damage_scaled = 100, cost = 2 },
}, 2)
t.eq(tied[1].id, "y", "a tie on damage is broken by the cheaper route")

-- --- component 1: easy damage ---------------------------------------------------

t.group("easy_damage")

local routes = {
    { id = "a", cost = 4, damage_scaled = 1000 },
    { id = "b", cost = 6, damage_scaled = 1500 },
    { id = "c", cost = 9, damage_scaled = 4000 },
    { id = "d", cost = 5, damage_scaled = nil },
}
local ed = PS.easy_damage(routes, { { id = "c", cost = 9, damage_scaled = 4000 },
                                    { id = "a", cost = 4, damage_scaled = 1000 } }, 6)
t.eq(ed.routes, 4, "every route is counted in the denominator")
t.eq(ed.cheap_routes, 3, "three routes are at or under the cut of 6 - the cut is inclusive")
t.eq(ed.cheap_routes_with_damage, 2, "but only two of them carry a scaled damage figure")
t.eq(ed.best_cheap_damage, 1500, "the best cheap route is the 1500, not the expensive 4000")
about(ed.best_pareto_ratio, 444.4444444, "the best damage/cost on the front is 4000/9", 1e-4)
about(ed.mean_pareto_ratio, 347.2222222, "and the mean is over both front routes", 1e-4)

local none = PS.easy_damage({ { id = "x", cost = 30, damage_scaled = 900 } }, {}, 6)
t.eq(none.cheap_routes, 0, "a character with nothing under the cut has no cheap routes")
t.is_nil(none.best_cheap_damage, "and no best cheap damage - nil, not zero")
t.is_nil(none.best_pareto_ratio, "an empty Pareto front gives no ratio either")
t.eq(PS.easy_damage({ { id = "x", cost = 0, damage_scaled = 5 } },
    { { id = "x", cost = 0, damage_scaled = 5 } }, 6).best_pareto_ratio, nil,
    "a zero-cost route is not divided by, it is skipped")

-- --- component 2: input shape ---------------------------------------------------

t.group("input_shape")

local shaped = {
    { id = "a", damage_scaled = 500, inputs = 4, hardest_motion = 0, switches = 0, simple_ratio = 0 },
    { id = "b", damage_scaled = 400, inputs = 8, hardest_motion = 4, switches = 2, simple_ratio = 0.5 },
    { id = "c", damage_scaled = 300, inputs = 12, hardest_motion = 8, switches = 1, simple_ratio = 0 },
}
local sh = PS.input_shape(shaped, { top_n = 3 })
t.eq(sh.top_n, 3, "the shape is taken over the routes actually found, not the number asked for")
about(sh.mean_input_count, 8, "mean input count over the three")
about(sh.mean_hardest_motion, 4, "mean longest motion")
t.eq(sh.big_motion_routes, 2, "two of the three need a motion of 4+ directions")
about(sh.big_motion_share, 2 / 3, "which is the 4+ share")
about(sh.mean_method_switches, 1, "mean input-method switches")
t.eq(sh.simple_routes, 1, "one route uses a simple input")
about(sh.simple_share, 1 / 3, "which is the simple share")

local two = PS.input_shape(shaped, { top_n = 2 })
t.eq(two.top_n, 2, "top_n really does cut the set")
about(two.mean_input_count, 6, "and the means are over the cut, not the whole set")

t.eq(PS.input_shape({ { id = "a", damage_scaled = 1, inputs = 3, hardest_motion = 3,
                       switches = 0, simple_ratio = 0 } }, { big_motion_digits = 3 })
        .big_motion_share, 1,
    "the 4+ threshold is an option, not a constant")
t.is_nil(PS.input_shape({ { id = "a", damage_scaled = nil, inputs = 3 } }, {}),
    "no route with a scaled damage figure means no shape at all - nil, not a zeroed table")
t.is_nil(PS.input_shape({}, {}), "and no routes means no shape")

-- --- component 3: timing comfort ------------------------------------------------

t.group("timing_comfort")

local wl = {
    { mechanism = "cancel" },
    { mechanism = "cancel" },
    { mechanism = "both", margin_frames = 1 },
    { mechanism = "link", margin_frames = 5 },
    { mechanism = "link", margin_frames = 3 },
    { mechanism = "link", margin_frames = 2 },
    { mechanism = "link", margin_frames = -4 },
    { mechanism = "link" },
    { mechanism = "unknown" },
    { },
}
local tc = PS.timing_comfort(wl, {})
t.eq(tc.pairs, 10, "every pair is counted")
t.eq(tc.cancel_pairs, 2, "two cancels")
t.eq(tc.both_pairs, 1, "one pair that is both cancellable and linkable")
t.eq(tc.link_pairs, 5, "five links")
t.eq(tc.unknown_pairs, 2, "an unknown mechanism and a missing one both land in unknown")
t.eq(tc.comfortable_links, 2, "two links have 3+ frames of margin - the threshold is inclusive")
t.eq(tc.tight_links, 1, "one link is tight at 1-2 frames")
t.eq(tc.negative_links, 1, "one link has no margin at all")
t.eq(tc.links_without_margin, 1, "and one link has no margin figure, counted apart")
about(tc.comfortable_link_share, 2 / 5, "comfortable share is over links only")
about(tc.cancel_share, 2 / 10, "cancel share is over every pair")
about(tc.unknown_share, 2 / 10, "so is the unknown share")
about(tc.forgiving_share, 5 / 10,
    "forgiving = cancels + both + comfortable links, over every pair")

local tighter = PS.timing_comfort(wl, { comfortable_margin = 5 })
t.eq(tighter.comfortable_links, 1, "raising the comfortable margin moves the line")
t.eq(tighter.comfortable_margin, 5, "and the table says which line it used")

t.is_nil(PS.timing_comfort({}, {}), "no worklist pairs means no timing component")
t.is_nil(PS.timing_comfort(nil, {}), "and neither does a missing worklist")
t.is_nil(PS.timing_comfort({ { mechanism = "cancel" } }, {}).comfortable_link_share,
    "a character with no links has no comfortable-link share - nil, not 0 or 1")

-- --- component 4: route availability --------------------------------------------

t.group("route_availability")

local avail = PS.route_availability({
    { length = 3, od_steps = 0, super_steps = 0, drc_steps = 0 },
    { length = 3, od_steps = 1, super_steps = 0, drc_steps = 0 },
    { length = 2, od_steps = 0, super_steps = 0, drc_steps = 0 },
    { length = 3, od_steps = 0, super_steps = 1, drc_steps = 0 },
    { length = 2, od_steps = 0, super_steps = 0, drc_steps = 1 },
})
t.eq(avail.routes, 5, "every route counted")
t.eq(avail.three_move_routes, 3, "three of them are 3-move routes")
t.eq(avail.no_gauge_routes, 2, "OD, super and a Drive Rush Cancel each rule a route out")
about(avail.no_gauge_share, 2 / 5, "which is the no-gauge share")
t.eq(avail.three_move_no_gauge_routes, 1, "and only one route is both 3 moves and gauge-free")
t.is_nil(PS.route_availability({}), "no routes means no availability component")

-- --- component 5: data quality ---------------------------------------------------

t.group("data_quality")

local q = PS.data_quality(
    { { id = "a", damage_scaled = 10, length = 3, guessed_join = 1, missing_data = 2 },
      { id = "b", damage_scaled = 5, length = 2, guessed_join = 0, missing_data = 0 } },
    { coverage = { matched = 80, rows = 100 },
      worklist_confidence = { high = 10, medium = 10, low = 30 }, worklist_pairs = 50 },
    true, { top_n = 2 })
about(q.join_share, 0.8, "the frame-data join share comes from characters.json's coverage")
about(q.low_confidence_share, 0.6, "and the low-confidence share from its worklist split")
about(q.confident_share, 0.4, "confident share is the complement")
t.eq(q.top_steps, 5, "the guessed-join share is over the steps of the top routes")
t.eq(q.guessed_join_steps, 1, "one of which was joined by guessing")
about(q.guessed_join_share, 0.2, "so a fifth of the steps")
about(q.exact_join_share, 0.8, "and four fifths were exact")
t.eq(q.missing_data_steps, 2, "steps with missing data are carried too")
t.eq(q.search_truncated, true, "and whether the search was cut short")

local thin = PS.data_quality({}, {}, false, {})
t.is_nil(thin.join_share, "no coverage in the index row means no join share - nil, not zero")
t.is_nil(thin.low_confidence_share, "and no worklist split means no confidence share")
t.is_nil(thin.guessed_join_share, "and no routes means no guessed-join share")
t.eq(thin.search_truncated, false, "a search that was not truncated says so")
t.is_nil(PS.data_quality({}, { coverage = { matched = 0, rows = 0 } }, false, {}).join_share,
    "a coverage of 0 rows is nil rather than a division by zero")

-- --- normalisation ----------------------------------------------------------------

t.group("normalise")

local n = PS.normalise({ 10, 20, 30 }, true)
about(n[1], 0, "min-max puts the smallest at 0 when higher is better")
about(n[2], 0.5, "and interpolates in between")
about(n[3], 1, "and the largest at 1")

local inv = PS.normalise({ 10, 20, 30 }, false)
about(inv[1], 1, "lower-is-better flips it: the smallest is the best")
about(inv[3], 0, "and the largest is the worst")

local flat = PS.normalise({ 4, 4, 4 }, true)
about(flat[1], 0.5, "no spread gives everyone 0.5, not 1 and not a division by zero")
about(flat[3], 0.5, "for all of them")

local holes = PS.normalise({ [1] = 1, [3] = 3 }, true)
about(holes[1], 0, "a missing value is skipped")
t.is_nil(holes[2], "and stays missing rather than becoming the minimum")
about(holes[3], 1, "the rest normalise over what is present")

t.eq(next(PS.normalise({}, true)), nil, "normalising nothing gives nothing")

t.group("weighted")

about((PS.weighted({ a = 1, b = 0 }, { a = 1, b = 1 })), 0.5, "a weighted mean of 1 and 0")
about((PS.weighted({ a = 1, b = 0 }, { a = 3, b = 1 })), 0.75, "at uneven weights")
local v, cov = PS.weighted({ a = 1 }, { a = 1, b = 3 })
about(v, 1, "a missing part is dropped and the rest renormalised, not treated as zero")
about(cov, 0.25, "and the coverage says how much of the weight was available")
local nv, ncov = PS.weighted({}, { a = 1 })
t.is_nil(nv, "nothing present at all gives nil rather than zero")
t.eq(ncov, 0, "with zero coverage")

-- --- the ranking --------------------------------------------------------------------

t.group("rank")

-- Three characters, hand-built so the expected order is obvious: Easy is best
-- on everything, Hard is worst on everything, Mid sits between.
local function raw(dmg, ratio, inputs, motion, big, switches, simple,
                   forgiving, no_gauge, join, low, guessed)
    return {
        easy_damage = { best_cheap_damage = dmg, best_pareto_ratio = ratio,
                        routes = 10, cheap_routes = 5, pareto_routes = 3 },
        input_shape = { top_n = 5, mean_input_count = inputs, mean_hardest_motion = motion,
                        big_motion_share = big, mean_method_switches = switches,
                        simple_share = simple, big_motion_routes = 0, simple_routes = 0 },
        timing_comfort = { pairs = 100, forgiving_share = forgiving, link_pairs = 10,
                           cancel_pairs = 50, both_pairs = 0, unknown_pairs = 0,
                           comfortable_links = 5, tight_links = 1, comfortable_margin = 3 },
        route_availability = { routes = 10, no_gauge_routes = no_gauge,
                               three_move_routes = 5, no_gauge_share = 0.5,
                               three_move_no_gauge_routes = 3 },
        data_quality = { join_share = join, low_confidence_share = low,
                         confident_share = 1 - low, guessed_join_share = guessed,
                         exact_join_share = 1 - guessed, join_matched = 90, join_rows = 100,
                         worklist_pairs = 100, low_confidence_pairs = low * 100,
                         top_n = 5, top_steps = 10, guessed_join_steps = 0,
                         search_truncated = false },
    }
end

local roster = {
    { character = "Mid", raw = raw(2000, 500, 8, 4, 0.5, 1, 0.5, 0.7, 50, 0.95, 0.3, 0.05) },
    { character = "Easy", raw = raw(3000, 700, 4, 1, 0.0, 0, 1.0, 0.9, 100, 1.00, 0.0, 0.00) },
    { character = "Hard", raw = raw(1000, 300, 14, 9, 1.0, 2, 0.0, 0.4, 10, 0.80, 0.7, 0.20) },
}
local ranked = PS.rank(roster)
t.eq(#ranked, 3, "every character comes back")
t.eq(ranked[1].character, "Easy", "the character that is best on every signal ranks first")
t.eq(ranked[3].character, "Hard", "and the worst ranks last")
t.eq(ranked[1].rank, 1, "the rank is written on the entry")
t.eq(ranked[3].rank, 3, "for everyone")
about(ranked[1].score, 100, "best on every signal is 100 under min-max", 1e-6)
about(ranked[3].score, 0, "and worst on every signal is 0 - that is min-max, not a judgement", 1e-6)
t.ok(ranked[2].score > 0 and ranked[2].score < 100, "the middle lands in between")
about(ranked[1].coverage, 1, "with every component available")
t.eq(#ranked[1].flags, 0, "and nothing to flag")
t.eq(ranked[1].damage_rank, 1, "the easy-damage-only ranking is written too")
t.eq(ranked[3].damage_rank, 3, "over the same set")
about(ranked[1].components.timing_comfort, 1, "the components are kept, not only the total")
t.ok(ranked[1].signals.input_shape.mean_input_count == 1,
    "and so are the normalised signals inside a component")

t.group("rank - ties")

local twins = {
    { character = "Bravo", raw = raw(2000, 500, 8, 4, 0.5, 1, 0.5, 0.7, 50, 0.95, 0.3, 0.05) },
    { character = "Alpha", raw = raw(2000, 500, 8, 4, 0.5, 1, 0.5, 0.7, 50, 0.95, 0.3, 0.05) },
}
local tied_rank = PS.rank(twins)
about(tied_rank[1].score, 50, "two identical characters both score 50 - no spread to read")
about(tied_rank[2].score, 50, "both of them")
t.eq(tied_rank[1].character, "Alpha", "and the tie is broken by name, so the order is stable")
t.eq(tied_rank[2].character, "Bravo", "not by whatever order they arrived in")

t.group("rank - missing data is flagged, not zeroed")

local partial = {
    { character = "Full", raw = raw(3000, 700, 4, 1, 0.0, 0, 1.0, 0.9, 100, 1.00, 0.0, 0.00) },
    { character = "Poor", raw = raw(1000, 300, 14, 9, 1.0, 2, 0.0, 0.4, 10, 0.80, 0.7, 0.20) },
    -- Nothing ran for this one: no routes at all, and only the index row's
    -- figures survive.
    { character = "Thin", raw = {
        data_quality = { join_share = 0.83, join_matched = 112, join_rows = 135,
                         low_confidence_share = 0.84, confident_share = 0.16,
                         worklist_pairs = 2797, low_confidence_pairs = 2346,
                         guessed_join_share = nil, exact_join_share = nil,
                         search_truncated = true },
    } },
}
local pr = PS.rank(partial)
local thin
for _, c in ipairs(pr) do if c.character == "Thin" then thin = c end end
t.ok(thin ~= nil, "the character with almost no data is still in the table")
t.is_nil(thin.components.easy_damage, "its missing components are nil")
t.is_nil(thin.components.input_shape, "every one of them")
t.ok(type(thin.score) == "number", "but it still has a score, from what was there")
t.ok(thin.score > 0, "and that score is not zero just because four components are missing")
about(thin.coverage, 0.10, "the coverage says only the 0.10 data-quality weight was available")

local kinds = {}
for _, f in ipairs(thin.flags) do kinds[f.kind] = f end
t.ok(kinds.incomplete ~= nil, "the missing components raise an incomplete flag")
t.eq(#kinds.incomplete.components, 4, "naming all four that could not be scored")
t.eq(kinds.incomplete.components[1], "easy damage", "in a stable, sorted order")
t.ok(kinds.weak_join ~= nil, "the weak frame-data join is flagged")
t.eq(kinds.weak_join.matched, 112, "carrying the numbers it was raised on")
t.ok(kinds.low_confidence ~= nil, "so is a mostly-low-confidence worklist")
t.ok(kinds.search_truncated ~= nil, "and a truncated route search")

t.group("flags")

t.eq(#PS.flags(raw(3000, 700, 4, 1, 0, 0, 1, 0.9, 100, 1.00, 0.0, 0.00)), 0,
    "a character with a complete, clean row is not flagged")
t.eq(#PS.flags(nil), 1, "a character with no raws at all is one flag: everything is missing")
t.eq(#PS.flags(nil)[1].components, 5, "and that flag names all five components")
local strict = PS.flags(raw(3000, 700, 4, 1, 0, 0, 1, 0.9, 100, 0.95, 0.5, 0.0),
    { weak_join = 0.99, heavy_low_confidence = 0.4 })
t.eq(#strict, 2, "the flag thresholds are options, not constants")

t.group("flag_text")

-- The flags are data so the page and the report can each phrase them; this is
-- the report's phrasing, and the one thing it must never do is lose a number.
t.eq(PS.flag_text({ kind = "weak_join", matched = 112, rows = 135, share = 112 / 135 }),
    "frame-data join 112/135 (83%)", "a weak join prints both counts and the percentage")
t.eq(PS.flag_text({ kind = "low_confidence", share = 0.84 }),
    "84% of the worklist is low confidence", "a low-confidence worklist prints its share")
t.eq(PS.flag_text({ kind = "search_truncated" }), "route search hit the beam limit",
    "a truncated search says so")
t.eq(PS.flag_text({ kind = "incomplete", components = { "easy damage", "input shape" } }),
    "no easy damage, input shape (component not scored)",
    "and an incomplete row names what was not scored")
t.eq(#PS.flag_texts({ { kind = "search_truncated" }, { kind = "low_confidence", share = 0.5 } }),
    2, "flag_texts maps the whole list")
t.eq(#PS.flag_texts(nil), 0, "and no flags is an empty list, not a crash")

return t.finish()
