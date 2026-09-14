-- Unit tests for tools/lua/planner.lua, and the pure half of tools/lua/pipeline.lua.
--
-- A plan decides which pairs the game machine spends its evening on. The things
-- it must not get wrong are tested here: a missing value never excludes a route,
-- a rejected pair never deletes one, a verified pair is not asked again, and
-- the keys match the ones the sweep writes into every trial.

local t = require("tests.lua.harness")
dofile("tools/lua/cli.lua")
local P = dofile("tools/lua/planner.lua")
local Pipeline = dofile("tools/lua/pipeline.lua")

local CHU = "\228\184\173"     -- 中
local JAKU = "\229\188\177"    -- 弱
local KYO = "\229\188\186"     -- 强

-- A move step as RouteSearch writes one.
local function mv(id, notation, method, extra)
    local s = { action_id = id, notation = notation, input_method = method or "manual",
                classic = "c" .. id }
    for k, v in pairs(extra or {}) do s[k] = v end
    return s
end

local DRC = { kind = "drive_rush_cancel" }

-- A scored route. score fields default to "spends nothing, and every figure known".
local function route(id, steps, score, basis)
    local n = 0
    for _, s in ipairs(steps) do if s.kind == nil then n = n + 1 end end
    local sc = { route_length = n, od_steps = 0, super_steps = 0, drive_rush_cancel_steps = 0,
                 predicted_drive_spend = 0, drive_spend_known = true, drive_spend_unknown_steps = 0,
                 predicted_super_spend = 0, predicted_damage = 1000, execution_cost = 5,
                 theoretical_confidence = "medium" }
    for k, v in pairs(score or {}) do sc[k] = v end
    return { id = id, steps = steps, offline_score = sc, min_confidence = sc.theoretical_confidence,
             basis = basis or { predicted_drive_spend = sc.predicted_drive_spend or 0 } }
end

local function ids(list)
    local out = {}
    for i, r in ipairs(list) do out[i] = r.id end
    return out
end

-- --- keys ------------------------------------------------------------------------

t.group("pair keys are the sweep's spelling")

t.eq(P.pair_key(601, "manual", 603, "simple"), "601:manual->603:simple",
    "a plain pair is runtime/Sweep's %d:%s->%d:%s")
t.eq(P.pair_key(601, "manual", 603, "manual", "drive_rush_cancel"), "601:manual->drc->603:manual",
    "a pair through a Drive Rush Cancel says ->drc->")
t.eq(P.pair_key(601.0, "manual", 603.0, "manual"), "601:manual->603:manual",
    "an id decoded from JSON as a float is spelled as the integer")
t.eq(P.combo_key(route("r", { mv(621, "2 + " .. CHU), mv(1206, "SP") })), "621>1206",
    "a combo key is the action ids alone, as sweepreport files combos")
t.is_nil(P.combo_key(route("r", { mv(621, "2 + " .. CHU), DRC, mv(603, CHU) })),
    "a route through a rush has no combo key: the combo list has no rush in it")

local rp = P.route_pairs(route("r", { mv(601, JAKU), mv(621, "2 + " .. CHU, "manual", { via_edge = "e1" }),
                                      DRC, mv(603, KYO, "manual", { via_edge = "e2" }) }))
t.eq(#rp, 2, "three moves with a rush between the last two are two pairs")
t.eq(rp[1].key, "601:manual->621:manual", "the first pair is plain")
t.eq(rp[1].edge_id, "e1", "and carries the edge its second step came through")
t.eq(rp[2].key, "621:manual->drc->603:manual", "the second goes through the rush")
t.eq(rp[2].drc, true, "and says so")

-- --- filters -----------------------------------------------------------------------

t.group("filters: starters")

local R1 = route("r1", { mv(604, CHU), mv(637, KYO) })
local R2 = route("r2", { mv(621, "2 + " .. CHU), mv(1206, "236236 + " .. CHU) })
local R3 = route("r3", { mv(601, JAKU), mv(604, CHU) })
local R4 = route("r4", { mv(633, "3 + " .. KYO), mv(940, "SP", "simple") })
local ALL = { R1, R2, R3, R4 }

local kept, rep = P.filter(ALL, { starter_button = CHU })
t.eq_list(ids(kept), { "r1", "r2" }, "starter_button keeps 中 with any direction, and only as the first move")
t.eq(rep.steps[1].removed, 2, "and counts the two it removed")
t.eq(rep.steps[1].before, 4, "out of four")
t.eq(rep.input, 4, "the report says how many came in")
t.eq(rep.kept, 2, "and how many survived")

kept = P.filter(ALL, { starter_button = "M" })
t.eq(#kept, 2, "M names the same button as 中")

kept = P.filter(ALL, { starter_button = CHU, starter_neutral = true })
t.eq_list(ids(kept), { "r1" }, "starter_neutral narrows it to no direction")

kept, rep = P.filter(ALL, { starter_notation = "2 + " .. CHU })
t.eq_list(ids(kept), { "r2" }, "starter_notation is exact")
t.eq(rep.steps[1].removed, 3, "and counts three removed")
kept = P.filter(ALL, { starter_notation = "2+" .. CHU })
t.eq(#kept, 0, "exact means exact: the catalog writes the spaces")

kept = P.filter(ALL, { starter_id = 601 })
t.eq_list(ids(kept), { "r3" }, "starter_id matches the first move's action id")

local UNREAD = route("u", { mv(999, "", "manual"), mv(604, CHU) })
kept, rep = P.filter({ UNREAD }, { starter_button = CHU })
t.eq(#kept, 1, "a first move whose notation cannot be read is kept")
t.ok(rep.flags["u"] ~= nil, "and flagged with why")
t.eq(rep.steps[1].flagged, 1, "and counted as kept on a gap")

t.group("filters: gauge")

local OD = route("od", { mv(621, "2 + " .. CHU), mv(924, "4 + AUTO + SP", "simple") },
    { od_steps = 1, predicted_drive_spend = 20000 })
local SA = route("sa", { mv(621, "2 + " .. CHU), mv(1206, "SP") }, { super_steps = 1 })
local RUSH = route("drc", { mv(621, "2 + " .. CHU), DRC, mv(604, CHU) },
    { drive_rush_cancel_steps = 1, predicted_drive_spend = 30000 })
local FREE = route("free", { mv(604, CHU), mv(637, KYO) })
local GAP = route("gap", { mv(604, CHU), mv(640, KYO) },
    { predicted_drive_spend = nil, drive_spend_known = false, drive_spend_unknown_steps = 1 },
    { predicted_drive_spend = 0 })
local GAP_SPENDS = route("gapspend", { mv(604, CHU), mv(641, KYO) },
    { predicted_drive_spend = nil, drive_spend_known = false, drive_spend_unknown_steps = 1 },
    { predicted_drive_spend = 10000 })
local G = { OD, SA, RUSH, FREE, GAP, GAP_SPENDS }

kept, rep = P.filter(G, { no_gauge = true })
t.eq_list(ids(kept), { "free", "gap" }, "no_gauge removes OD, super, rush and known spend")
t.eq(rep.steps[1].removed, 4, "four removed")
t.ok(rep.flags["gap"] ~= nil, "a route with no Drive figure is kept and flagged, not removed")
t.is_nil(rep.flags["free"], "a route known to be free is not flagged")

kept, rep = P.filter(G, { no_super = true })
t.eq(rep.steps[1].removed, 1, "no_super removes only the super")
kept, rep = P.filter(G, { no_drive_rush = true })
t.eq(rep.steps[1].removed, 1, "no_drive_rush removes only the rush")

kept, rep = P.filter(G, { max_drive_bars = 2 })
t.eq_list(ids(kept), { "od", "sa", "free", "gap", "gapspend" },
    "max_drive_bars 2 removes the 30000 rush and keeps the 20000 OD")
t.ok(rep.flags["gapspend"] ~= nil, "a known floor under the budget with a gap is kept and flagged")
kept = P.filter(G, { max_drive_bars = 0 })
t.eq_list(ids(kept), { "sa", "free", "gap" }, "a known FLOOR over the budget removes: that spend is known")

t.group("filters: steps, confidence, input method")

local LONG = route("long", { mv(601, JAKU), mv(604, CHU), mv(637, KYO) }, { theoretical_confidence = "low" })
local SIMPLE = route("simple", { mv(604, CHU), mv(940, "SP", "simple") }, { theoretical_confidence = "high" })
local ASSIST = route("assist", { mv(604, CHU), mv(950, "AUTO", "assist") })
local NOMETHOD = route("nomethod", { mv(604, CHU), { action_id = 637, notation = KYO } })
local S = { LONG, SIMPLE, ASSIST, NOMETHOD }

kept, rep = P.filter(S, { max_steps = 2 })
t.eq(rep.steps[1].removed, 1, "max_steps counts moves")
kept, rep = P.filter(S, { min_steps = 3 })
t.eq_list(ids(kept), { "long" }, "min_steps counts moves")
kept, rep = P.filter(S, { min_confidence = "medium" })
t.eq_list(ids(kept), { "simple", "assist", "nomethod" }, "min_confidence drops a low route")
kept, rep = P.filter(S, { input_method = "manual" })
t.eq_list(ids(kept), { "long", "nomethod" }, "manual keeps manual only, and a move with no method on a flag")
t.ok(rep.flags["nomethod"] ~= nil, "the move with no method is the flag")
kept = P.filter(S, { input_method = "simple" })
t.eq(#kept, 3, "simple allows simple and manual")
kept = P.filter(S, { input_method = "assist" })
t.eq(#kept, 4, "assist allows everything")

kept, rep = P.filter(S, { min_steps = 2, max_steps = 2, min_confidence = "high" })
t.eq(#rep.steps, 3, "each condition given is a step of its own")
t.eq(rep.steps[1].name, "min_steps", "applied in FILTER_ORDER")
t.eq(rep.steps[3].removed + rep.steps[2].removed + rep.steps[1].removed, 3,
    "and the removals add up to what went")

local bad, err = P.filter(S, { max_setps = 2 })
t.is_nil(bad, "a mistyped condition is refused")
t.ok(tostring(err):find("max_setps") ~= nil, "by name")
t.is_nil((P.filter(S, { input_method = "auto" })), "an input method that is not one is refused")
t.is_nil((P.filter(S, { min_confidence = "certain" })), "so is a confidence that is not one")

kept, rep = P.filter(G, { no_gauge = true, starter_id = 999 })
t.eq(next(rep.flags), nil, "flags on routes a later filter removed are dropped with them")

-- --- ranking -----------------------------------------------------------------------------

t.group("rank")

local A = route("a", { mv(1, JAKU), mv(2, CHU) }, { predicted_damage = 3000, execution_cost = 9,
    theoretical_confidence = "low" })
local B = route("b", { mv(1, JAKU), mv(3, CHU) }, { predicted_damage = 2000, execution_cost = 3,
    theoretical_confidence = "high" })
local C = route("c", { mv(1, JAKU), mv(4, CHU) }, { predicted_damage = 2000, execution_cost = 3,
    theoretical_confidence = "high" })

local ranked, info = P.rank({ C, B, A }, "scaled_damage")
t.eq_list(ids(ranked), { "a", "b", "c" }, "with no scaled figure anywhere, damage orders, ties by id")
t.eq(info.fallback, true, "and the fallback is said")
t.eq(info.field, "predicted_damage", "naming the field that was used")
t.ok(info.fallback_reason ~= nil, "with a reason")

local AS = route("as", { mv(1, JAKU), mv(2, CHU) }, { predicted_damage = 3000, predicted_damage_scaled = 1500 })
local BS = route("bs", { mv(1, JAKU), mv(3, CHU) }, { predicted_damage = 2000, predicted_damage_scaled = 1800 })
local NS = route("ns", { mv(1, JAKU), mv(4, CHU) }, { predicted_damage = 9000 })
ranked, info = P.rank({ AS, NS, BS }, "scaled_damage")
t.eq(info.fallback, false, "a set that carries the scaled figure is ordered on it")
t.eq_list(ids(ranked), { "bs", "as", "ns" }, "scaled, never mixed with unscaled; a route without it goes last")
t.eq(info.missing, 1, "and is counted")

ranked = P.rank({ A, B, C }, "damage")
t.eq_list(ids(ranked), { "a", "b", "c" }, "damage")
ranked = P.rank({ A, C, B }, "simple")
t.eq_list(ids(ranked), { "b", "c", "a" }, "simple is lowest execution cost first, ties by id")
ranked = P.rank({ A, C, B }, "confidence")
t.eq_list(ids(ranked), { "b", "c", "a" }, "confidence is highest first, ties by id")
t.is_nil((P.rank({ A }, "fun")), "a sort that is not one is refused")

-- --- pairs_needed ---------------------------------------------------------------------------

t.group("pairs_needed")

local X1 = route("x1", { mv(601, JAKU), mv(604, CHU), mv(637, KYO) })
local X2 = route("x2", { mv(601, JAKU), mv(604, CHU), mv(640, KYO) })
local X3 = route("x3", { mv(621, "2 + " .. CHU), DRC, mv(604, CHU) })
local X4 = route("x4", { mv(621, "2 + " .. CHU), mv(604, CHU) })

local need = P.pairs_needed({ X1, X2, X3, X4 }, 3)
local keys = {}
for i, p in ipairs(need) do keys[i] = p.key end
t.eq_list(keys, { "601:manual->604:manual", "604:manual->637:manual", "604:manual->640:manual",
                  "621:manual->drc->604:manual" },
    "first-needed order, a shared pair listed once, and the top N only")
t.eq_list(need[1].needed_by_ranks, { 1, 2 }, "a shared pair names every rank that needs it")
t.eq_list(need[3].needed_by_ranks, { 2 }, "a pair only route 2 needs names route 2")
t.eq(need[4].drc, true, "a DRC pair is marked")
need = P.pairs_needed({ X1, X2, X3, X4 })
t.eq(#need, 5, "with no N, every route; the plain 621->604 is a different pair from the rushed one")

-- --- known and annotate -------------------------------------------------------------------------

t.group("known_from folds cohorts")

local function edge(key, status, cal, stable)
    return { edge_id = key, status = status, stable = stable or false, attempts = 2,
             successes = status == "verified" and 2 or 0, negatives = status == "rejected" and 2 or 0,
             unanswered = 0, cohort = { calibration_id = cal } }
end

local known = P.known_from({
    edge("601:manual->604:manual", "verified", "c2", true),
    edge("604:manual->637:manual", "rejected", "c1"),
    edge("604:manual->637:manual", "verified", "c2"),
    edge("604:manual->640:manual", "rejected", "c2"),
    edge("621:manual->604:manual", "runtime_pending", "c2"),
}, { { key = "621>604", status = "confirmed" }, { key = "601>604>640", status = "once" } })

t.eq(known.pairs["601:manual->604:manual"].status, "verified", "one verified cohort is verified")
t.eq(known.pairs["604:manual->637:manual"].status, "verified", "a link in any cohort outweighs a no in another")
t.eq(known.pairs["604:manual->637:manual"].mixed, true, "and that is marked mixed")
t.eq(#known.pairs["604:manual->637:manual"].cohorts, 2, "with both cohorts kept")
t.eq(known.pairs["604:manual->640:manual"].status, "rejected", "only no is rejected")
t.eq(known.pairs["621:manual->604:manual"].status, "pending", "nothing answered is pending")

t.group("annotate: verified skipped, rejected kept, confirmed route")

local Y1 = route("y1", { mv(601, JAKU), mv(604, CHU), mv(637, KYO) })      -- all verified
local Y2 = route("y2", { mv(601, JAKU), mv(604, CHU), mv(640, KYO) })      -- one rejected
local Y3 = route("y3", { mv(621, "2 + " .. CHU), mv(604, CHU) })           -- confirmed combo, pending pair
local Y4 = route("y4", { mv(602, JAKU), mv(610, KYO) })                     -- untested
local Ys = { Y1, Y2, Y3, Y4 }

local ann = P.annotate(P.pairs_needed(Ys), Ys, known)
local by = {}
for _, p in ipairs(ann.pairs) do by[p.key] = p end
t.eq(by["601:manual->604:manual"].skip, "verified", "a verified pair is skipped")
t.eq(by["604:manual->640:manual"].known_status, "rejected", "a rejected pair is marked")
t.is_nil(by["604:manual->640:manual"].skip, "and NOT skipped")
t.eq(by["621:manual->604:manual"].skip, "route_confirmed",
    "a pair only a confirmed combo needs is skipped as already known")
t.eq(by["602:manual->610:manual"].known_status, "untested", "a pair no log mentions is untested")
t.is_nil(by["602:manual->610:manual"].skip, "and is swept")

t.eq(ann.routes[1].all_pairs_verified, true, "a route whose every pair is verified says so")
t.eq(ann.routes[2].has_rejected_pair, true, "a route through a rejected pair is flagged")
t.eq_list(ann.routes[2].rejected_pairs, { "604:manual->640:manual" }, "naming the pair")
t.eq(ann.routes[3].confirmed, true, "a route the logs list as a confirmed combo is confirmed")
t.eq(ann.routes[2].combo_status, "once", "a combo seen once is carried, not called confirmed")
t.eq(ann.routes[2].confirmed, false, "and is not confirmed")

ann = P.annotate(P.pairs_needed(Ys), Ys, known, { include_verified = true })
by = {}
for _, p in ipairs(ann.pairs) do by[p.key] = p end
t.is_nil(by["601:manual->604:manual"].skip, "include_verified keeps a verified pair")

t.group("annotate: an answer under another id with the same buttons")

-- The catalog lists 弱 as 601 and 611; the search kept 601, the sweep folded
-- onto 611 and wrote that into its trials.
local NOTATION = { ["601:manual"] = JAKU, ["611:manual"] = JAKU, ["604:manual"] = CHU,
                   ["662:manual"] = "6 + " .. KYO, ["1206:manual"] = "236236 + " .. CHU }
local known_g = P.known_from({
    edge("611:manual->604:manual", "verified", "c2"),
    edge("662:manual->611:manual", "rejected", "c2"),
}, { { key = "611>1206", status = "confirmed", inputs = { { JAKU, "236236 + " .. CHU } } } },
    NOTATION)
local G1 = route("g1", { mv(601, JAKU), mv(604, CHU) })
local G2 = route("g2", { mv(662, "6 + " .. KYO), mv(601, JAKU) })
local G3 = route("g3", { mv(601, JAKU), mv(1206, "236236 + " .. CHU) })
local gann = P.annotate(P.pairs_needed({ G1, G2, G3 }), { G1, G2, G3 }, known_g)
t.eq(gann.pairs[1].known_status, "verified", "601 -> 604 is answered by the trials of 611 -> 604")
t.eq_list(gann.pairs[1].known_as, { "611:manual->604:manual" }, "and says which key answered it")
t.eq(gann.pairs[1].skip, "verified", "so it is not asked again")
t.eq(gann.pairs[2].known_status, "rejected", "a rejection is found the same way")
t.eq(gann.routes[2].has_rejected_pair, true, "and flags the route")
t.eq(gann.routes[3].confirmed, true, "a combo linked under 611 confirms the route kept as 601, by its inputs")
local exact = P.annotate(P.pairs_needed({ G1 }), { G1 }, P.known_from({
    edge("601:manual->604:manual", "rejected", "c1"), edge("611:manual->604:manual", "verified", "c2") },
    nil, NOTATION))
t.eq(exact.pairs[1].known_status, "rejected", "an answer under the pair's own key wins over its group")
t.is_nil(exact.pairs[1].known_as, "and names no other key")
local nogroup = P.annotate(P.pairs_needed({ G1 }), { G1 },
    P.known_from({ edge("611:manual->604:manual", "verified", "c2") }))
t.eq(nogroup.pairs[1].known_status, "untested", "without notations nothing is grouped")
t.eq(P.group_pair_key("manual", JAKU, "manual", CHU, "drive_rush_cancel"),
    "manual|" .. JAKU .. "->drc->manual|" .. CHU, "a group key spells the rush as the pair key does")

t.group("plan: demotes but never deletes")

local plan = P.plan(Ys, { sort = "damage", top = 4, known = known })
t.eq(#plan.routes, 4, "every route is still in the plan")
t.eq(plan.routes[4].id, "y2", "the route through a rejected pair is ranked after the clean ones")
t.eq(plan.routes[4].sort_rank, 2, "and remembers where the sort put it")
t.eq(plan.through_rejected, 1, "the count of routes through a rejected pair is reported")
local sweep_keys = {}
for i, p in ipairs(plan.sweep) do sweep_keys[i] = p.key end
t.eq_list(sweep_keys, { "602:manual->610:manual", "604:manual->640:manual" },
    "the sweep holds the untested pair, then the rejected one; verified and confirmed are skipped")
t.eq(#plan.skipped, 3, "the skipped pairs are listed")
t.eq_list(plan.sweep[2].needed_by_ranks, { 4 }, "needed_by_ranks are plan ranks")

plan = P.plan(Ys, { sort = "damage", top = 2, known = known })
t.eq_list(ids(plan.routes), { "y1", "y3" }, "with a top 2, the clean routes fill it")
t.eq(#plan.demoted_out, 1, "and the route the sort had in the top 2 is listed as moved out")
t.eq(plan.demoted_out[1].id, "y2", "by id")

plan = P.plan({ Y2 }, { sort = "damage", top = 5, known = known })
t.eq(#plan.routes, 1, "a plan with only rejected routes still has them")
t.eq(plan.sweep[1].key, "604:manual->640:manual", "and sweeps the rejected pair")

plan = P.plan(Ys, { sort = "damage", top = 4, known = known, demote_rejected = false })
t.eq_list(ids(plan.routes), { "y1", "y2", "y3", "y4" }, "demote_rejected = false keeps sort order")

local YC = route("yc", { mv(621, "2 + " .. CHU), mv(604, CHU) }, { predicted_damage = 1 })
local known_c = P.known_from({ edge("621:manual->604:manual", "rejected", "c1") },
    { { key = "621>604", status = "confirmed" } })
plan = P.plan({ YC, Y4 }, { sort = "damage", top = 2, known = known_c })
t.eq(plan.routes[1].id, "y4", "ordered by damage")
t.eq(plan.routes[2].id, "yc", "a confirmed combo is not demoted for a pair rejected on its own")
t.eq(plan.sweep[#plan.sweep].known_status, "rejected", "but its rejected pair is still asked again")

t.is_nil((P.plan(Ys, { cond = { nope = true } })), "a bad condition refuses the whole plan")

-- --- the command line -----------------------------------------------------------------------------

t.group("command line")

local argv = P.normalize_argv({ "--no-gauge", "--no-drive-rush", "--drive-rush", "--top", "5",
                                "--include-verified", "false", "--no-demote-rejected" })
t.eq_list(argv, { "--cond-no-gauge", "true", "--cond-no-drive-rush", "true", "--drive-rush", "true",
                  "--top", "5", "--include-verified", "false", "--no-demote-rejected" },
    "switches get keys and values of their own; --no-demote-rejected is left to Cli")
local Cli = dofile("tools/lua/cli.lua")
local opt = Cli.parse(argv, {})
local cond = P.conditions_from(opt)
t.eq(cond.no_gauge, true, "--no-gauge turns the condition on")
t.eq(cond.no_drive_rush, true, "--no-drive-rush is the condition")
t.eq(opt.drive_rush, true, "and --drive-rush is the search option, apart from it")
t.eq(opt.demote_rejected, false, "--no-demote-rejected turns demotion off")

t.eq((P.from_ansi("\146\134")), CHU, "Shift_JIS 中 from a Windows command line becomes UTF-8")
t.eq((P.from_ansi("2 + \146\134")), "2 + " .. CHU, "inside a notation too")
t.eq((P.from_ansi("\139\173")), KYO, "Shift_JIS 強 becomes the catalog's 强")
local same, converted = P.from_ansi(CHU)
t.eq(same, CHU, "valid UTF-8 is left alone")
t.eq(converted, false, "and says it was not converted")
t.eq(P.conditions_from({ starter_button = "\146\134" }).starter_button, CHU,
    "conditions_from converts the starter")
t.eq(P.button_name("\229\188\183"), "H", "the Japanese 強 names the heavy button")

t.eq(P.default_name({ starter_button = CHU, no_gauge = true }, "scaled_damage", 20),
    "starter-M-nogauge-scaled_damage-top20", "a default name is built from the conditions, in ASCII")
t.eq(P.default_name({ starter_notation = "2 + " .. CHU }, "damage", 5), "starter-2M-damage-top5",
    "a notation is spelled by its direction and button names")
t.eq(P.slug("a b/c"), "a_b_c", "a name is made safe for a file name")

-- --- pipeline: the pure half ------------------------------------------------------------------------

t.group("pipeline: worklist records match explore.lua's")

local plain = {
    id = "e1", confidence = "high", context_known = true,
    from = { action_id = 621, input_method = "manual", notation = "2 + " .. CHU },
    to = { action_id = 1206, input_method = "simple", notation = "SP" },
    basis = { from_startup = 7, from_active = "3", from_recovery = 12, from_hitstop = 9,
              from_hitstun = 16, from_on_hit = 5, to_startup = 5, margin_frames = 0 },
}
local rushed = {
    id = "e2", confidence = "low", via = "drive_rush_cancel",
    from = { action_id = 621, input_method = "manual", notation = "2 + " .. CHU },
    to = { action_id = 604, input_method = "manual", notation = CHU },
    basis = { from_startup = 7, from_on_hit = 5, from_drc_on_hit = 9, to_startup = 5,
              drc_margin_frames = 4, drive_cost = 30000, margin_frames = 99 },
}
t.eq(Pipeline.edge_pair_key(plain), "621:manual->1206:simple", "an edge's pair key")
t.eq(Pipeline.edge_pair_key(rushed), "621:manual->drc->604:manual", "a rushed edge's pair key")
t.eq(Pipeline.edge_pair_key(rushed),
    P.pair_key(621, "manual", 604, "manual", "drive_rush_cancel"),
    "the pipeline and the planner spell a key the same way")

local item = Pipeline.worklist_item(plain)
t.eq(item.margin_frames, 0, "a plain record carries the margin")
t.eq(item.a_hitstun, 16, "and A's frames")
t.eq(item.context_known, true, "and the parent vouch (#49)")
t.is_nil(item.via, "and no via")
item = Pipeline.worklist_item(rushed)
t.eq(item.via, "drive_rush_cancel", "a DRC record carries via")
t.eq(item.drc_margin_frames, 4, "and the DRC margin")
t.eq(item.drive_cost, 30000, "and the drive cost")
t.is_nil(item.margin_frames, "and not the plain margin, as explore.lua writes it")

local ctx = { opt = { character = "Zangief", scheme = "modern" }, meta = { ac_sha256 = "aa", bcm_sha256 = "bb" },
              provenance = { generated_at = "now", game_patch = "p", frame_data = nil }, idx = {} }
local doc, derr = Pipeline.worklist_doc(ctx, {})
t.is_nil(doc, "a worklist built from frame data with no attribution is refused")
t.ok(tostring(derr):find("attribution") ~= nil, "saying why")
ctx.provenance.frame_data = { source = "s", commit = "c", license = "CC-BY-SA-4.0" }
doc = Pipeline.worklist_doc(ctx, { { a_id = 1 } }, { plan = { name = "x" } })
t.eq(doc.schema, "ce.worklist.v1", "the envelope is a worklist")
t.eq(doc.ac_sha256, "aa", "with the identity hashes")
t.eq(doc.count, 1, "the count")
t.eq(doc.plan.name, "x", "and the extra fields")
t.ok(type(doc.attribution) == "table", "and the attribution block")

return t.finish()
