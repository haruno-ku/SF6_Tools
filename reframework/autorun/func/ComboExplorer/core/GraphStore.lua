-- =========================================================
-- ComboExplorer/core/GraphStore.lua - holds candidate edges as a graph, and
-- knows when the graph no longer describes the game it was built from.
-- Pure: edges in, adjacency out.
-- =========================================================
--
-- WHY A STORE AND NOT A TABLE
--
-- Two jobs a plain list of edges cannot do.
--
-- Adjacency, so route search can ask "what follows this move" without scanning
-- everything. That part is bookkeeping.
--
-- Invalidation, which is not. Every edge is keyed on action ids that came from
-- one AC/BCM pair on one game patch. If either moves, the ids may still exist
-- and may still resolve - and mean different moves. A stale graph does not
-- error; it silently describes a game nobody is playing. So the store carries
-- the identity of the data it was built from and refuses to be merged with
-- results measured against a different one.
--
-- MIXING THEORY AND MEASUREMENT
--
-- The same store holds theoretical candidates and, later, confirmed edges from
-- real trials. A measurement always wins over a guess, and a rejection is a
-- measurement: an edge the game refused is not the same as one nobody tried,
-- and route search must not keep proposing it.

local Schema = require("func/ComboExplorer/core/Schema")

local M = { name = "ComboExplorer.GraphStore" }

local function node_key(n)
    return ("%d:%s"):format(n.action_id, n.input_method)
end
M.node_key = node_key

-- identity: what the graph is about. Two graphs may only be merged when these
-- agree, because an action id is only meaningful relative to them.
function M.new(identity)
    return {
        identity = {
            character = identity and identity.character,
            game_patch = identity and identity.game_patch,
            ac_sha256 = identity and identity.ac_sha256,
            bcm_sha256 = identity and identity.bcm_sha256,
            calibration_id = identity and identity.calibration_id,
        },
        edges = {},        -- [edge id] = edge
        out = {},          -- [from key] = { edge, ... }
        nodes = {},        -- [key] = node
        counts = { theoretical = 0, verified = 0, rejected = 0, runtime_pending = 0 },
        -- The status each edge was last COUNTED under. Not derivable from the
        -- edge itself: a caller may hold a reference and transition it in place,
        -- after which the record no longer remembers which bucket it is in and
        -- the tally drifts without anything failing.
        counted = {},      -- [edge id] = status
    }
end

local function note_node(g, n)
    local k = node_key(n)
    if not g.nodes[k] then
        g.nodes[k] = { action_id = n.action_id, input_method = n.input_method,
                       notation = n.notation, classic = n.classic,
                       category = n.category, canonical_status = n.canonical_status }
    end
    return k
end

-- Adds one edge. A rejected edge is kept rather than dropped: "the game refused
-- this" and "nobody has tried this" are different, and only the first should
-- stop it being proposed again.
function M.add(g, edge)
    if type(edge) ~= "table" or edge.id == nil then return false, "not an edge" end

    local existing = g.edges[edge.id]
    if existing then
        -- A measurement replaces a guess. A guess never replaces a measurement.
        --
        -- Compared against the counted status rather than the live record, for
        -- the same reason the counted table exists: an edge transitioned in
        -- place would otherwise be judged against its own new value.
        local was = g.counted[edge.id] or existing.status
        local was_runtime = (was == Schema.STATUS.VERIFIED or was == Schema.STATUS.REJECTED)
        local is_runtime = (edge.status == Schema.STATUS.VERIFIED
                         or edge.status == Schema.STATUS.REJECTED)
        if was_runtime and not is_runtime and existing ~= edge then
            return false, "refusing to overwrite a measured edge with a theoretical one"
        end
        g.counts[was] = (g.counts[was] or 1) - 1
    end

    g.edges[edge.id] = edge
    g.counts[edge.status] = (g.counts[edge.status] or 0) + 1
    g.counted[edge.id] = edge.status

    local from_key = note_node(g, edge.from)
    note_node(g, edge.to)

    g.out[from_key] = g.out[from_key] or {}
    -- Replace in place when the id is already present, so adjacency never holds
    -- two versions of the same edge.
    for i, e in ipairs(g.out[from_key]) do
        if e.id == edge.id then g.out[from_key][i] = edge return true end
    end
    g.out[from_key][#g.out[from_key] + 1] = edge
    return true
end

-- Straight from a CandidateGenerator result. The identity is the caller's to
-- supply: the generator does not know which build its catalog was dumped from.
function M.build(candidates, identity)
    local g = M.new(identity)
    M.add_all(g, candidates)
    return g
end

function M.add_all(g, edges)
    local added, refused = 0, {}
    for _, e in ipairs(edges or {}) do
        local ok, why = M.add(g, e)
        if ok then added = added + 1 else refused[#refused + 1] = { id = e.id, reason = why } end
    end
    return added, refused
end

-- Edges leaving a node, minus the ones the game has already refused.
--
-- include_rejected is there for reporting, never for search: proposing a route
-- through an edge that was measured and failed would waste the trial that
-- already answered it.
function M.neighbours(g, key, opts)
    opts = opts or {}
    local out = {}
    for _, e in ipairs(g.out[key] or {}) do
        local keep = true
        if e.status == Schema.STATUS.REJECTED and not opts.include_rejected then keep = false end
        if keep and opts.min_confidence then
            local rank = { low = 1, medium = 2, high = 3 }
            if (rank[e.confidence] or 0) < (rank[opts.min_confidence] or 0) then keep = false end
        end
        if keep and opts.exclude_context_dependent and e.context_dependent then keep = false end
        if keep then out[#out + 1] = e end
    end
    return out
end

function M.edge(g, id) return g.edges[id] end
function M.node(g, key) return g.nodes[key] end

-- Every node, in a stable order. pairs() over a hash is arbitrary, and a search
-- that enumerates its start set that way returns different routes run to run.
function M.nodes_list(g)
    local out = {}
    for k, n in pairs(g.nodes) do
        out[#out + 1] = { key = k, action_id = n.action_id, input_method = n.input_method,
                          notation = n.notation, classic = n.classic, category = n.category,
                          canonical_status = n.canonical_status }
    end
    table.sort(out, function(a, b)
        if a.action_id ~= b.action_id then return a.action_id < b.action_id end
        return a.input_method < b.input_method
    end)
    return out
end

function M.node_count(g)
    local n = 0
    for _ in pairs(g.nodes) do n = n + 1 end
    return n
end

function M.edge_count(g)
    local n = 0
    for _ in pairs(g.edges) do n = n + 1 end
    return n
end

-- --- identity ----------------------------------------------------------------

-- Do these two graphs describe the same game? Only the fields that actually
-- change the meaning of an action id are compared; a missing field on either
-- side is unknown, and unknown is not a match.
function M.identity_matches(a, b)
    local problems = {}
    for _, f in ipairs({ "character", "game_patch", "ac_sha256", "bcm_sha256" }) do
        local x, y = a and a[f], b and b[f]
        if x == nil or y == nil then
            problems[#problems + 1] = { field = f, problem = "unknown on one side" }
        elseif x ~= y then
            problems[#problems + 1] = { field = f, problem = ("%s vs %s"):format(tostring(x), tostring(y)) }
        end
    end
    return #problems == 0, problems
end

-- Folds confirmed results in. Refuses outright when the identities disagree,
-- because a link measured on last month's patch is not evidence about this one
-- and quietly accepting it is how a dataset rots without anyone noticing.
function M.merge_results(g, results, identity)
    local ok, problems = M.identity_matches(g.identity, identity)
    if not ok then
        return false, { reason = "identity mismatch - these results are about a different build",
                        problems = problems }
    end
    local applied, refused = M.add_all(g, results)
    return true, { applied = applied, refused = refused }
end

-- Marks everything theoretical again. Used when the data behind the graph has
-- moved: what was measured was measured about a different game.
function M.invalidate(g, reason)
    local n = 0
    for _, e in pairs(g.edges) do
        if e.status ~= Schema.STATUS.THEORETICAL then
            e.status = Schema.STATUS.THEORETICAL
            e.runtime_verified = false
            e.evidence = nil
            e.invalidated_reason = reason
            n = n + 1
        end
    end
    g.counts = { theoretical = M.edge_count(g), verified = 0, rejected = 0, runtime_pending = 0 }
    for id in pairs(g.edges) do g.counted[id] = Schema.STATUS.THEORETICAL end
    return n
end

-- --- reporting ---------------------------------------------------------------

function M.summary(g)
    local by_reason, by_confidence = {}, {}
    for _, e in pairs(g.edges) do
        for _, r in ipairs(e.reasons or {}) do by_reason[r] = (by_reason[r] or 0) + 1 end
        by_confidence[e.confidence or "unknown"] = (by_confidence[e.confidence or "unknown"] or 0) + 1
    end
    return {
        identity = g.identity,
        nodes = M.node_count(g),
        edges = M.edge_count(g),
        by_status = g.counts,
        by_reason = by_reason,
        by_confidence = by_confidence,
    }
end

-- Nodes with no way in, and nodes with no way out. Both are worth seeing: a
-- move nothing reaches will never appear in a route however good it is.
function M.orphans(g)
    local has_in = {}
    for _, e in pairs(g.edges) do has_in[node_key(e.to)] = true end
    local unreachable, dead_ends = {}, {}
    for k, n in pairs(g.nodes) do
        if not has_in[k] then unreachable[#unreachable + 1] = n end
        if #(g.out[k] or {}) == 0 then dead_ends[#dead_ends + 1] = n end
    end
    local function by_id(a, b) return a.action_id < b.action_id end
    table.sort(unreachable, by_id)
    table.sort(dead_ends, by_id)
    return { unreachable = unreachable, dead_ends = dead_ends }
end

return M
