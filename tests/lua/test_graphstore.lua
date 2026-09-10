-- Unit tests for func/ComboExplorer/core/GraphStore.lua
--
-- Two things are being defended here.
--
-- A measurement outranks a guess. Once the game has answered a pair, a later
-- offline regeneration must not quietly overwrite the answer with a candidate.
--
-- And a graph knows what game it is about. Action ids are only meaningful
-- against one AC/BCM pair on one patch; results measured against another are not
-- evidence about this one, however well-formed they look.

local t = require("tests.lua.harness")
local GraphStore = require("func/ComboExplorer/core/GraphStore")
local CG = require("func/ComboExplorer/core/CandidateGenerator")
local Catalog = require("func/ComboExplorer/core/Catalog")
local FrameData = require("func/ComboExplorer/core/FrameData")
local Schema = require("func/ComboExplorer/core/Schema")

local cat = Catalog.build(dofile("tests/lua/fixtures/zangief_catalog.lua"))
local idx = FrameData.index(dofile("data/frame-data/zangief.lua"))

local IDENTITY = {
    character = "zangief",
    game_patch = "2026-08-03",
    ac_sha256 = "aaaa",
    bcm_sha256 = "bbbb",
}

local gen = CG.generate(cat, idx, {
    from = { categories = { "normal", "command_normal" }, input_methods = { "manual" } },
    include_followups = false,
})

-- --- building from real generator output -------------------------------------

t.group("building")

local g = GraphStore.build(gen.candidates, IDENTITY)

t.eq(GraphStore.edge_count(g), #gen.candidates, "every candidate lands in the graph")
t.ok(GraphStore.node_count(g) > 0, "and nodes appear (" .. GraphStore.node_count(g) .. ")")
t.eq(g.counts.theoretical, #gen.candidates, "all of them theoretical")
t.eq(g.counts.verified, 0, "and none verified, because nothing has been run")

t.eq(g.identity.character, "zangief", "identity is carried")
t.eq(g.identity.game_patch, "2026-08-03", "including the patch")

-- The node key has to distinguish input methods: the same action id reached by
-- a manual motion and by a simple button is two different things to execute.
t.eq(GraphStore.node_key({ action_id = 621, input_method = "manual" }), "621:manual",
     "a node key names both the action and how it is produced")
t.ok(GraphStore.node_key({ action_id = 621, input_method = "simple" })
     ~= GraphStore.node_key({ action_id = 621, input_method = "manual" }),
     "and the two input methods do not collide")

-- --- adjacency ---------------------------------------------------------------

t.group("adjacency")

local nb = GraphStore.neighbours(g, "633:manual")
t.ok(#nb > 0, "2HK has successors (" .. #nb .. ")")
for _, e in ipairs(nb) do
    t.eq(e.from.action_id, 633, "and every one of them leaves 2HK")
end

t.eq_list(GraphStore.neighbours(g, "not-a-node"), {}, "an unknown node has no successors")

-- Filters, because route search will not want every candidate at every depth.
local strict = GraphStore.neighbours(g, "633:manual", { min_confidence = "high" })
t.eq(#strict, 0, "no high-confidence successors among ground normals, as expected")
local med = GraphStore.neighbours(g, "633:manual", { min_confidence = "medium" })
t.ok(#med > 0 and #med <= #nb, "medium admits some but not more than all")

local list = GraphStore.nodes_list(g)
t.eq(#list, GraphStore.node_count(g), "every node is enumerable")
local ordered = true
for i = 2, #list do
    if list[i - 1].action_id > list[i].action_id then ordered = false end
end
t.ok(ordered, "in a stable order, so a search is reproducible run to run")

-- --- a measurement outranks a guess ------------------------------------------

t.group("measurement versus guess")

local sample = gen.candidates[1]
local id = sample.id

-- Copy it, run it through the status machine, and put the result back.
local measured = {}
for k, v in pairs(sample) do measured[k] = v end
measured.provenance = { game_patch = "2026-08-03", calibration_id = "cal-1" }
t.ok(Schema.transition(measured, Schema.STATUS.RUNTIME_PENDING), "queued for a trial")
t.ok(Schema.transition(measured, Schema.STATUS.VERIFIED,
     { attempts = 3, successes = 3, delays = { 3, 4, 5 } }), "and verified with evidence")

t.ok(GraphStore.add(g, measured), "a measured edge replaces the candidate")
t.eq(GraphStore.edge(g, id).status, "verified", "and the graph now holds the measurement")
t.eq(g.counts.verified, 1, "the tally moves")
t.eq(g.counts.theoretical, #gen.candidates - 1, "out of the theoretical bucket, not on top of it")

-- The regeneration case: offline runs again and produces the same pair as a
-- candidate. It must not erase what the game said.
local regenerated = {}
for k, v in pairs(sample) do regenerated[k] = v end
local ok, why = GraphStore.add(g, regenerated)
t.eq(ok, false, "a fresh candidate does not overwrite a measured edge")
t.ok(type(why) == "string" and #why > 0, "and says why (" .. tostring(why) .. ")")
t.eq(GraphStore.edge(g, id).status, "verified", "the measurement survives")

-- Re-adding the very same table - the in-place transition case - is not an
-- overwrite and must be allowed, without the tally drifting.
local before = g.counts.verified
t.ok(GraphStore.add(g, measured), "re-adding the same measured record is fine")
t.eq(g.counts.verified, before, "and does not double-count it")

-- --- a rejection is a result, not an absence ----------------------------------

t.group("rejected edges")

local other = gen.candidates[2]
local refused = {}
for k, v in pairs(other) do refused[k] = v end
refused.provenance = { game_patch = "2026-08-03", calibration_id = "cal-1" }
Schema.transition(refused, Schema.STATUS.RUNTIME_PENDING)
t.ok(Schema.transition(refused, Schema.STATUS.REJECTED,
     { attempts = 3, successes = 0, verdict = "whiff" }), "a refused pair carries evidence too")
GraphStore.add(g, refused)

local from_key = GraphStore.node_key(refused.from)
local visible = GraphStore.neighbours(g, from_key)
for _, e in ipairs(visible) do
    t.ok(e.id ~= refused.id, "a rejected edge is not offered to search")
end
local all = GraphStore.neighbours(g, from_key, { include_rejected = true })
local found = false
for _, e in ipairs(all) do if e.id == refused.id then found = true end end
t.ok(found, "but it is still there for reporting - it is a result, not an absence")

-- --- identity ----------------------------------------------------------------

t.group("identity")

local same, problems = GraphStore.identity_matches(IDENTITY, IDENTITY)
t.eq(same, true, "a graph matches itself")
t.eq(#problems, 0, "with nothing to report")

local patched = {}
for k, v in pairs(IDENTITY) do patched[k] = v end
patched.bcm_sha256 = "cccc"
local differs, why2 = GraphStore.identity_matches(IDENTITY, patched)
t.eq(differs, false, "a different BCM is a different game")
t.ok(#why2 > 0, "and the field is named")

-- Unknown is not a match. A results file with no checksums cannot prove it is
-- about this build, and accepting it would be the quietest possible way to
-- corrupt the dataset.
local vague = { character = "zangief", game_patch = "2026-08-03" }
t.eq((GraphStore.identity_matches(IDENTITY, vague)), false,
     "missing checksums do not count as agreement")

t.group("merging results")

local g2 = GraphStore.build(gen.candidates, IDENTITY)
local merged, report = GraphStore.merge_results(g2, { measured }, IDENTITY)
t.eq(merged, true, "results measured on the same build merge")
t.eq(report.applied, 1, "and are applied")

local blocked, report2 = GraphStore.merge_results(g2, { measured }, patched)
t.eq(blocked, false, "results from a different build are refused outright")
t.ok(report2.reason:find("different build") ~= nil, "with the reason stated")
t.ok(#report2.problems > 0, "and the mismatching field listed")

-- --- invalidation ------------------------------------------------------------

t.group("invalidation")

t.eq(g2.counts.verified, 1, "g2 holds one measurement")
local dropped = GraphStore.invalidate(g2, "game patched")
t.eq(dropped, 1, "invalidating demotes it")
t.eq(g2.counts.verified, 0, "nothing is verified any more")
t.eq(GraphStore.edge(g2, id).status, "theoretical", "it is a candidate again")
t.eq(GraphStore.edge(g2, id).runtime_verified, false, "and no longer claims to have been run")
t.is_nil(GraphStore.edge(g2, id).evidence, "the stale evidence is gone")
t.eq(GraphStore.edge(g2, id).invalidated_reason, "game patched", "with the reason recorded")

-- After invalidation the demoted edge is an ordinary candidate again, so the
-- overwrite guard must no longer fire on it.
t.ok(GraphStore.add(g2, regenerated), "and a regenerated candidate is accepted")

-- --- reporting ---------------------------------------------------------------

t.group("summary")

local s = GraphStore.summary(g)
t.eq(s.edges, GraphStore.edge_count(g), "the summary counts the edges")
t.eq(s.identity.character, "zangief", "and names the character")
t.ok(s.by_reason.frame_link ~= nil, "reasons are tallied")
t.ok(s.by_confidence.medium ~= nil, "so is confidence")

local orph = GraphStore.orphans(g)
t.ok(orph.unreachable ~= nil and orph.dead_ends ~= nil, "orphans are reported")
for _, n in ipairs(orph.dead_ends) do
    t.eq(#GraphStore.neighbours(g, GraphStore.node_key(n), { include_rejected = true }), 0,
         ("dead end %d really has no successors"):format(n.action_id))
end

-- --- degenerate input --------------------------------------------------------

t.group("degenerate input")

local empty = GraphStore.new(IDENTITY)
t.eq(GraphStore.edge_count(empty), 0, "a new graph is empty")
t.eq(GraphStore.node_count(empty), 0, "with no nodes")
t.eq((GraphStore.add(empty, nil)), false, "nil is not an edge")
t.eq((GraphStore.add(empty, { from = {}, to = {} })), false, "nor is an edge with no id")

return t.finish()
