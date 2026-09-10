-- =========================================================
-- ComboExplorer/core/RouteSearch.lua - walks the candidate graph into multi-step
-- route candidates. Pure: a graph in, routes out.
-- =========================================================
--
-- ONE ROUTE REPRESENTATION
--
-- What comes out of here is the same record the runner will consume and the
-- same record a confirmed combo is written against - `ce.route.v1`, produced
-- offline as `theoretical` and moved along by the status machine when the game
-- has had its say. There is no separate "offline route" that gets translated
-- later: a second representation is a second place for the two halves to drift
-- apart, and the drift would show up as routes that cannot be compiled.
--
-- The consequence is that a step carries `delay_ticks = nil` here, and it stays
-- nil. How many ticks to wait between two moves is the thing the sweep exists
-- to measure. Filling it in with a frame-table subtraction would produce a
-- route that looks executable and is not, and worse, would look measured.
--
-- WHAT PRUNES AND WHAT DOES NOT
--
-- Every limit here is a bound on the SEARCH, never a claim about the game. A
-- route dropped for exceeding the step limit is not a route that fails; it is a
-- route this run did not look at. So each cap reports what it dropped, and a
-- missing value never prunes: if the source has no drive figure for a move, a
-- drive budget cannot judge that move, and the route survives with the gap
-- recorded rather than being deleted on a number nobody has.
--
-- LOOPS
--
-- Repeating a move is legitimate - light chains do it - so a plain "no repeats"
-- rule would delete real combos. Three separate bounds instead: how often one
-- action may appear at all, how often it may appear back to back, and how often
-- one edge may be traversed. The last is what actually stops A->B->A->B running
-- forever; the first two shape what comes out.

local Schema = require("func/ComboExplorer/core/Schema")
local GraphStore = require("func/ComboExplorer/core/GraphStore")
local FrameData = require("func/ComboExplorer/core/FrameData")

local M = { name = "ComboExplorer.RouteSearch" }

-- Defaults, all overridable. These are search bounds; none of them is a
-- statement about what Street Fighter 6 allows.
M.DEFAULTS = {
    max_steps            = 4,     -- route length, in moves
    min_steps            = 2,     -- a single move is not a route
    max_repeat_per_action = 2,    -- how often one action may appear in a route
    max_consecutive_repeat = 2,   -- how often it may appear back to back
    max_repeat_per_edge  = 1,     -- traversing one edge twice is the cycle case
    beam_width           = 200,   -- partial routes kept at each depth
    max_routes           = 500,   -- total emitted
    max_od_steps         = 1,     -- OD moves per route
    max_super_steps      = 1,     -- super arts per route
    min_confidence       = nil,   -- nil = take everything, including low
    allow_context_dependent = true,
    -- The catalog cannot say which action id a given input produces when
    -- several share a notation - 601 and 602 are both "弱" - so the graph
    -- carries all of them and the search walks all of them. That is honest
    -- about the data and noisy in a report, because the variants are the same
    -- buttons pressed in the same order. Collapsing folds them to one route
    -- carrying the count of ids it stands for; it is off by default because it
    -- discards a distinction the runtime is going to resolve.
    collapse_canonical_variants = false,
}

local CONF_RANK = { low = 1, medium = 2, high = 3 }

-- --- per-move facts ----------------------------------------------------------

-- Everything about one node that a budget or a heuristic might want. Absent
-- values stay nil; `known` says which of them were actually there.
local function facts_for(node, frame_idx)
    local f = { damage = nil, drive_gain = nil, super_gain = nil,
                is_od = (node.category == "od_special"),
                is_super = (node.category == "super"),
                known = {} }
    if frame_idx then
        local rec = FrameData.lookup(frame_idx, node.classic)
        if rec then
            f.damage = FrameData.damage(rec)
            f.drive_gain = FrameData.drive_gain(rec)
            f.super_gain = FrameData.super_gain(rec)
        end
    end
    f.known.damage = f.damage ~= nil
    f.known.drive = f.drive_gain ~= nil
    f.known.super = f.super_gain ~= nil
    return f
end

-- --- the running state of a partial route ------------------------------------

local function new_partial(node, facts)
    return {
        nodes = { node },
        edges = {},
        action_count = { [node.action_id] = 1 },
        edge_count = {},
        resources = {
            predicted_damage = facts.damage or 0,
            damage_known_steps = facts.known.damage and 1 or 0,
            predicted_drive_gain = facts.drive_gain or 0,
            drive_known_steps = facts.known.drive and 1 or 0,
            predicted_super_gain = facts.super_gain or 0,
            super_known_steps = facts.known.super and 1 or 0,
            od_steps = facts.is_od and 1 or 0,
            super_steps = facts.is_super and 1 or 0,
            unknown_steps = (facts.known.damage and facts.known.drive and facts.known.super)
                and 0 or 1,
        },
        confidence_counts = {},
        min_confidence_rank = 4,
        context_dependent = false,
        unknowns = {},
        unknown_detail = {},
    }
end

local function copy_partial(p)
    local q = {
        nodes = {}, edges = {},
        action_count = {}, edge_count = {},
        resources = {},
        confidence_counts = {},
        min_confidence_rank = p.min_confidence_rank,
        context_dependent = p.context_dependent,
        unknowns = {}, unknown_detail = {},
    }
    for i, v in ipairs(p.nodes) do q.nodes[i] = v end
    for i, v in ipairs(p.edges) do q.edges[i] = v end
    for k, v in pairs(p.action_count) do q.action_count[k] = v end
    for k, v in pairs(p.edge_count) do q.edge_count[k] = v end
    for k, v in pairs(p.resources) do q.resources[k] = v end
    for k, v in pairs(p.confidence_counts) do q.confidence_counts[k] = v end
    for i, v in ipairs(p.unknowns) do q.unknowns[i] = v end
    for k, v in pairs(p.unknown_detail) do q.unknown_detail[k] = v end
    return q
end

local function note_unknown(p, what, why)
    if p.unknown_detail[what] == nil then
        p.unknowns[#p.unknowns + 1] = what
        p.unknown_detail[what] = why
    end
end

-- --- admissibility -----------------------------------------------------------

-- Why this edge may not extend this partial route, or nil if it may. Every
-- rejection is a search bound, and every one of them is counted so the caller
-- can see what the run did not look at.
local function why_not(p, edge, node, facts, cfg)
    if #p.nodes >= cfg.max_steps then return "max_steps" end

    local id = node.action_id
    if (p.action_count[id] or 0) >= cfg.max_repeat_per_action then
        return "max_repeat_per_action"
    end
    if (p.edge_count[edge.id] or 0) >= cfg.max_repeat_per_edge then
        return "max_repeat_per_edge"
    end

    local run = 0
    for i = #p.nodes, 1, -1 do
        if p.nodes[i].action_id == id then run = run + 1 else break end
    end
    if run >= cfg.max_consecutive_repeat then return "max_consecutive_repeat" end

    if not cfg.allow_context_dependent and edge.context_dependent then
        return "context_dependent_excluded"
    end

    -- Resource budgets. These count steps rather than gauge units, because the
    -- gauge cost of an OD move appears in no frame table - counting a thing that
    -- is actually there beats inventing a number for a thing that is not.
    if facts.is_od and p.resources.od_steps >= cfg.max_od_steps then
        return "max_od_steps"
    end
    if facts.is_super and p.resources.super_steps >= cfg.max_super_steps then
        return "max_super_steps"
    end

    return nil
end

local function extend(p, edge, node, facts)
    local q = copy_partial(p)
    q.nodes[#q.nodes + 1] = node
    q.edges[#q.edges + 1] = edge
    q.action_count[node.action_id] = (q.action_count[node.action_id] or 0) + 1
    q.edge_count[edge.id] = (q.edge_count[edge.id] or 0) + 1

    local r = q.resources
    r.predicted_damage = r.predicted_damage + (facts.damage or 0)
    if facts.known.damage then r.damage_known_steps = r.damage_known_steps + 1 end
    r.predicted_drive_gain = r.predicted_drive_gain + (facts.drive_gain or 0)
    if facts.known.drive then r.drive_known_steps = r.drive_known_steps + 1 end
    r.predicted_super_gain = r.predicted_super_gain + (facts.super_gain or 0)
    if facts.known.super then r.super_known_steps = r.super_known_steps + 1 end
    if facts.is_od then r.od_steps = r.od_steps + 1 end
    if facts.is_super then r.super_steps = r.super_steps + 1 end
    if not (facts.known.damage and facts.known.drive and facts.known.super) then
        r.unknown_steps = r.unknown_steps + 1
    end

    local c = edge.confidence or "low"
    q.confidence_counts[c] = (q.confidence_counts[c] or 0) + 1
    q.min_confidence_rank = math.min(q.min_confidence_rank, CONF_RANK[c] or 1)
    if edge.context_dependent then q.context_dependent = true end

    for _, u in ipairs(edge.requires_runtime_validation or {}) do
        note_unknown(q, u, (edge.unknown_detail and edge.unknown_detail[u])
            or "carried from an edge in this route")
    end
    return q
end

-- --- ranking -----------------------------------------------------------------

-- The default beam heuristic, and it is a heuristic: it decides which partial
-- routes are worth carrying to the next depth, not which routes are good. The
-- real ordering is Scoring's job, and a caller that has one passes it as
-- opts.rank.
--
-- Predicted damage is a frame-table sum with no scaling applied, so it is used
-- for ordering only and never written out as a damage figure.
function M.beam_heuristic(p)
    local conf = (p.min_confidence_rank == 4) and 1 or p.min_confidence_rank
    local dmg = p.resources.predicted_damage or 0
    local penalty = (p.resources.unknown_steps or 0) * 100
    return conf * 10000 + dmg - penalty
end

-- --- building the record -----------------------------------------------------

local function route_id(nodes)
    local parts = {}
    for i, n in ipairs(nodes) do
        parts[i] = ("%d:%s"):format(n.action_id, n.input_method)
    end
    return table.concat(parts, ">")
end

-- What the player actually does, with the action ids left out. Two routes with
-- the same shape key are the same buttons in the same order; which action id
-- each produces is the unresolved-canonical question.
local function shape_key(nodes)
    local parts = {}
    for i, n in ipairs(nodes) do
        parts[i] = ("%s|%s"):format(tostring(n.notation or n.classic), n.input_method)
    end
    return table.concat(parts, ">")
end

local RANK_NAME = { "low", "medium", "high" }

local function to_route(p, cfg, provenance)
    local steps = {}
    for i, n in ipairs(p.nodes) do
        local via = (i > 1) and p.edges[i - 1] or nil
        steps[i] = {
            index = i,
            action_id = n.action_id,
            input_method = n.input_method,
            notation = n.notation,
            classic = n.classic,
            category = n.category,
            canonical_status = n.canonical_status,
            via_edge = via and via.id or nil,
            edge_reasons = via and via.reasons or nil,
            edge_confidence = via and via.confidence or nil,
            context_dependent = (via and via.context_dependent) or false,
            -- Measured by the sweep. Never filled in from a frame table.
            delay_ticks = nil,
        }
    end

    local edge_ids = {}
    for i, e in ipairs(p.edges) do edge_ids[i] = e.id end

    return Schema.new(Schema.KIND.ROUTE, {
        id = route_id(p.nodes),
        character = cfg.character,
        control_scheme = cfg.control_scheme,
        position = cfg.position,
        counter = cfg.counter,
        steps = steps,
        edge_ids = edge_ids,
        shape_key = shape_key(p.nodes),
        length = #p.nodes,
        min_confidence = RANK_NAME[p.min_confidence_rank] or "low",
        confidence_counts = p.confidence_counts,
        context_dependent = p.context_dependent,
        requires_runtime_validation = p.unknowns,
        unknown_detail = p.unknown_detail,
        -- Raw per-route sums from the frame source, for Scoring to work from.
        -- Not a score, and deliberately not called one.
        basis = {
            predicted_damage_sum = p.resources.predicted_damage,
            damage_known_steps = p.resources.damage_known_steps,
            predicted_drive_gain = p.resources.predicted_drive_gain,
            drive_known_steps = p.resources.drive_known_steps,
            predicted_super_gain = p.resources.predicted_super_gain,
            super_known_steps = p.resources.super_known_steps,
            od_steps = p.resources.od_steps,
            super_steps = p.resources.super_steps,
            steps_with_missing_data = p.resources.unknown_steps,
        },
        provenance = provenance,
    })
end

-- --- the search --------------------------------------------------------------

-- g          : a GraphStore
-- opts       : any of M.DEFAULTS, plus
--              starts       list of node keys (default: every node with a successor)
--              rank         function(partial) -> number, for beam pruning
--              frame_idx    a FrameData index, for damage and resource sums
--              character / control_scheme / position / counter : carried onto
--                           each route, since a route is only about one setup
--              provenance   as built by Schema.provenance
--
-- Returns { routes, stats }.
function M.search(g, opts)
    opts = opts or {}
    if type(g) ~= "table" or type(g.edges) ~= "table" then return nil, "not a graph" end

    -- Merged by name rather than by iterating opts, because two of the settings
    -- default to nil and a pairs() merge cannot see a key that is not there.
    local cfg = {}
    for k, v in pairs(M.DEFAULTS) do cfg[k] = v end
    cfg.min_confidence = opts.min_confidence
    if opts.allow_context_dependent ~= nil then
        cfg.allow_context_dependent = opts.allow_context_dependent
    end
    for _, k in ipairs({ "max_steps", "min_steps", "max_repeat_per_action",
                         "max_consecutive_repeat", "max_repeat_per_edge", "beam_width",
                         "max_routes", "max_od_steps", "max_super_steps",
                         "collapse_canonical_variants" }) do
        if opts[k] ~= nil then cfg[k] = opts[k] end
    end
    for _, k in ipairs({ "character", "control_scheme", "position", "counter" }) do
        cfg[k] = opts[k]
    end

    local rank = opts.rank or M.beam_heuristic
    local provenance = opts.provenance or Schema.provenance({})

    local stats = {
        starts = 0, expansions = 0, emitted = 0,
        pruned = {},                 -- reason -> count
        beam_dropped = {},           -- depth -> how many partials the beam discarded
        truncated_routes = 0,        -- routes not emitted because of max_routes
        by_length = {},
    }
    local function prune(reason)
        stats.pruned[reason] = (stats.pruned[reason] or 0) + 1
    end

    -- Per-node facts, resolved once.
    local facts_cache = {}
    local function facts(node, key)
        if facts_cache[key] == nil then
            facts_cache[key] = facts_for(node, opts.frame_idx)
        end
        return facts_cache[key]
    end

    -- Starts: every node with somewhere to go. A follow-up never has outgoing
    -- edges (the generator only ever points AT one), so it drops out here
    -- without a rule of its own.
    local start_keys = opts.starts
    if not start_keys then
        start_keys = {}
        for _, n in ipairs(GraphStore.nodes_list(g)) do
            if #GraphStore.neighbours(g, n.key, { min_confidence = cfg.min_confidence }) > 0 then
                start_keys[#start_keys + 1] = n.key
            end
        end
    end

    local frontier = {}
    for _, key in ipairs(start_keys) do
        local node = GraphStore.node(g, key)
        if node then
            node = { action_id = node.action_id, input_method = node.input_method,
                     notation = node.notation, classic = node.classic,
                     category = node.category, canonical_status = node.canonical_status,
                     key = key }
            frontier[#frontier + 1] = new_partial(node, facts(node, key))
            stats.starts = stats.starts + 1
        end
    end

    local routes = {}
    local by_shape = {}
    local depth = 1
    while #frontier > 0 and depth < cfg.max_steps do
        depth = depth + 1
        local next_frontier = {}

        for _, p in ipairs(frontier) do
            local last = p.nodes[#p.nodes]
            local nb = GraphStore.neighbours(g, last.key or GraphStore.node_key(last), {
                min_confidence = cfg.min_confidence,
                exclude_context_dependent = not cfg.allow_context_dependent,
            })
            for _, e in ipairs(nb) do
                stats.expansions = stats.expansions + 1
                local key = GraphStore.node_key(e.to)
                local node = GraphStore.node(g, key) or e.to
                node = { action_id = node.action_id, input_method = node.input_method,
                         notation = node.notation, classic = node.classic,
                         category = node.category, canonical_status = node.canonical_status,
                         key = key }
                local f = facts(node, key)
                local no = why_not(p, e, node, f, cfg)
                if no then
                    prune(no)
                else
                    next_frontier[#next_frontier + 1] = extend(p, e, node, f)
                end
            end
        end

        -- Beam. Sorted by the heuristic, ties broken on the route id so a rerun
        -- of the same graph produces the same routes in the same order.
        if #next_frontier > cfg.beam_width then
            local scored = {}
            for i, p in ipairs(next_frontier) do
                scored[i] = { p = p, s = rank(p), id = route_id(p.nodes) }
            end
            table.sort(scored, function(a, b)
                if a.s ~= b.s then return a.s > b.s end
                return a.id < b.id
            end)
            stats.beam_dropped[depth] = #next_frontier - cfg.beam_width
            local kept = {}
            for i = 1, cfg.beam_width do kept[i] = scored[i].p end
            next_frontier = kept
        end

        if depth >= cfg.min_steps then
            for _, p in ipairs(next_frontier) do
                local route = to_route(p, cfg, provenance)
                local seen = cfg.collapse_canonical_variants and by_shape[route.shape_key] or nil
                if seen then
                    -- Same buttons, different action id. Recorded on the route
                    -- that is kept, so the count is visible rather than lost.
                    seen.canonical_variants = (seen.canonical_variants or 1) + 1
                    seen.variant_route_ids[#seen.variant_route_ids + 1] = route.id
                    stats.collapsed_variants = (stats.collapsed_variants or 0) + 1
                elseif #routes < cfg.max_routes then
                    if cfg.collapse_canonical_variants then
                        route.canonical_variants = 1
                        route.variant_route_ids = {}
                        by_shape[route.shape_key] = route
                    end
                    routes[#routes + 1] = route
                    stats.emitted = stats.emitted + 1
                    stats.by_length[#p.nodes] = (stats.by_length[#p.nodes] or 0) + 1
                else
                    stats.truncated_routes = stats.truncated_routes + 1
                end
            end
        end

        frontier = next_frontier
    end

    stats.routes = #routes
    -- Said out loud rather than left to be inferred from a suspiciously round
    -- number: a cap that silently truncates reads as "this was everything".
    stats.complete = (stats.truncated_routes == 0)
    local dropped = 0
    for _, n in pairs(stats.beam_dropped) do dropped = dropped + n end
    stats.beam_dropped_total = dropped
    if dropped > 0 then stats.complete = false end

    return { routes = routes, stats = stats, config = cfg }
end

return M
