-- Unit tests for func/ComboExplorer/core/CatalogAudit.lua
--
-- Runs against the real Zangief catalog, because the failure it guards against
-- is data drift: a catalog generated on one patch, used against another, where
-- every action id has quietly moved. That failure is silent - ids that no
-- longer exist simply never appear, and ids that mean something else are
-- recorded under the old name.

local t = require("tests.lua.harness")
local Catalog = require("func/ComboExplorer/core/Catalog")
local Audit = require("func/ComboExplorer/core/CatalogAudit")

local RAW = dofile("tests/lua/fixtures/zangief_catalog.lua")
local cat = Catalog.build(RAW)

-- Builds an observed-id table from the catalog's own ids, so a "healthy"
-- session can be simulated.
local function observe(ids, n)
    local out = {}
    for _, id in ipairs(ids) do out[id] = n or 1 end
    return out
end

local function catalog_ids(limit)
    local seen, out = {}, {}
    for _, row in ipairs(cat.rows) do
        if not seen[row.action_id] then
            seen[row.action_id] = true
            out[#out + 1] = row.action_id
            if limit and #out >= limit then break end
        end
    end
    return out
end

-- --- a healthy session -------------------------------------------------------

t.group("a healthy session")

local r = Audit.audit(cat, observe(catalog_ids(40), 3))
t.ok(r ~= nil, "the audit runs")
t.eq(r.probe, "D.catalog_audit", "the report names itself")
t.eq(r.character, "Zangief", "and the character")
t.ok(r.ac_sha256 ~= nil, "carrying the AC checksum the ids belong to")
t.eq(r.matched, 40, "all forty observed ids matched")
t.eq(#r.unknown_observed, 0, "nothing unknown")
t.ok(r.conclusive, "and the result is conclusive")
t.ok(r.verdict:find("matched the catalog", 1, true) ~= nil, "with a verdict in words")

-- --- the drift case ----------------------------------------------------------

t.group("the catalog does not describe this game")

-- Every id shifted: what a patch that renumbers actions would look like.
local shifted = {}
for _, id in ipairs(catalog_ids(40)) do shifted[id + 100000] = 3 end
r = Audit.audit(cat, shifted)
t.eq(r.matched, 0, "nothing matched")
t.ok(r.conclusive, "which is itself a conclusion")
t.ok(r.verdict:find("NOT ONE", 1, true) ~= nil, "and it is stated bluntly")

-- Mostly unknown is the subtler version and gets its own verdict.
local mixed = observe(catalog_ids(10), 2)
for i = 1, 40 do mixed[900000 + i] = 1 end
r = Audit.audit(cat, mixed)
t.ok(r.verdict:find("unknown to the catalog", 1, true) ~= nil, "a mostly-unknown session is flagged")
t.eq(#r.unknown_observed, 40, "and the unknown ids are listed")
t.ok(r.unknown_observed[1].action_id ~= nil, "with their ids")

-- --- too little data ---------------------------------------------------------

t.group("too little data")

r = Audit.audit(cat, observe(catalog_ids(5), 1))
t.eq(r.conclusive, false, "five ids is not enough to conclude from")
t.ok(r.verdict:find("play for longer", 1, true) ~= nil, "and the operator is told so")

r = Audit.audit(cat, {})
t.eq(r.conclusive, false, "no observations is not a verdict")

-- --- what was never seen -----------------------------------------------------

t.group("unseen standalone moves")

-- Only standalone rows count as "should have appeared". A follow-up or an
-- assist-combo step is not expected in free play, so counting it as missing
-- would be noise.
r = Audit.audit(cat, observe(catalog_ids(40), 3))
for _, id in ipairs(r.unseen_standalone) do
    local found_standalone = false
    for _, row in ipairs(cat.rows) do
        if row.action_id == id and row.standalone then found_standalone = true end
    end
    t.ok(found_standalone, ("unseen id %d is a standalone row"):format(id))
end

-- --- evidence toward the canonical question ----------------------------------

t.group("ambiguous groups collect evidence")

r = Audit.audit(cat, observe(catalog_ids(40), 3))
t.ok(#r.ambiguous_groups > 0, "ambiguous groups are reported")

for _, g in ipairs(r.ambiguous_groups) do
    t.eq(g.canonical_status, "unverified", "and remain unverified - free play is not a controlled input")
end

-- One member seen and the rest never is a hint worth surfacing.
local crouch = nil
for _, g in pairs(cat.groups) do
    local ids = {}
    for _, id in ipairs(g.action_ids) do ids[id] = true end
    if ids[617] and ids[618] and ids[619] then crouch = g end
end
t.ok(crouch ~= nil, "the crouching-light group exists")

r = Audit.audit(cat, { [617] = 12, [1] = 5, [2] = 5, [3] = 5, [4] = 5, [5] = 5,
                       [6] = 5, [7] = 5, [8] = 5, [9] = 5, [10] = 5, [11] = 5,
                       [12] = 5, [13] = 5, [14] = 5, [15] = 5, [16] = 5, [19] = 5,
                       [20] = 5, [21] = 5, [22] = 5 })
local found
for _, g in ipairs(r.ambiguous_groups) do
    if g.display_group == crouch.display_group then found = g end
end
t.ok(found ~= nil, "the group appears in the audit")
t.eq(found.single_candidate, 617, "with the one member that was actually seen")
t.eq(#found.unseen, 2, "and the two that were not")

-- --- degenerate input --------------------------------------------------------

t.group("degenerate input")

t.is_nil(Audit.audit(nil, {}), "a nil catalog is refused")
t.is_nil(Audit.audit({}, {}), "a table that is not a catalog is refused")

return t.finish()
