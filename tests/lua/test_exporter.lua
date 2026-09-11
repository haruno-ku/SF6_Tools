-- Unit tests for func/ComboExplorer/core/Exporter.lua
--
-- The documents this builds are read on another machine by somebody who cannot
-- ask what they mean, so everything worth testing is about what the file says
-- about itself: that nothing in it has been run, which build it is about, and
-- where the numbers came from.
--
-- The gate is the other half. A verified record in a file headed "nothing here
-- has been run" would be a fact filed among guesses, and the only thing worse
-- than losing it is not noticing.

local t = require("tests.lua.harness")
local Exporter = require("func/ComboExplorer/core/Exporter")
local Schema = require("func/ComboExplorer/core/Schema")
local CG = require("func/ComboExplorer/core/CandidateGenerator")
local Catalog = require("func/ComboExplorer/core/Catalog")
local FrameData = require("func/ComboExplorer/core/FrameData")
local GraphStore = require("func/ComboExplorer/core/GraphStore")
local RouteSearch = require("func/ComboExplorer/core/RouteSearch")
local Scoring = require("func/ComboExplorer/core/Scoring")

local cat = Catalog.build(dofile("tests/lua/fixtures/zangief_catalog.lua"))
local idx = FrameData.index(dofile("data/frame-data/zangief.lua"))

local PROV = Schema.provenance({
    game_patch = "command_display@2026-08-03",
    command_display = { character = "Zangief", fighter_id = 6,
                        generated_at = "2026-08-03T00:00:00.000Z",
                        ac_sha256 = "753d02", bcm_sha256 = "09e933",
                        schema = "xt.command_display.v1" },
    frame_data = { source = "RyoSogawa/sf6-sensei", commit = "a64f2ac",
                   url = "https://wiki.supercombo.gg/w/Street_Fighter_6",
                   license = "CC-BY-SA", fetched_at = "2026-09-10T09:58:49Z" },
    explorer_version = "test",
    generated_at = "2026-09-10T10:00:00Z",
})

local gen = CG.generate(cat, idx, {
    from = { categories = { "normal", "command_normal" }, input_methods = { "manual" } },
    to = { categories = { "normal", "command_normal", "special", "super" },
           input_methods = { "manual" } },
    include_followups = true,
    provenance = PROV,
})
local g = GraphStore.build(gen.candidates, { character = "zangief",
    game_patch = "p", ac_sha256 = "a", bcm_sha256 = "b" })
local found = RouteSearch.search(g, { frame_idx = idx, character = "zangief",
    control_scheme = "modern", max_steps = 3, beam_width = 500, max_routes = 300,
    provenance = PROV })
local routes = Scoring.apply(found.routes)

local OPTS = {
    character = "zangief", control_scheme = "modern",
    position = "midscreen", counter = "none",
    generated_at = "2026-09-10T10:00:00Z",
    provenance = PROV,
}

-- --- the header says what the file is ----------------------------------------

t.group("the document header")

local doc, rejected = Exporter.edges(gen.candidates, OPTS)
t.ok(doc ~= nil, "edges export")
t.eq(doc.schema, "ce.candidate_edges.v1", "with a schema tag")
t.eq(doc.runtime_verified, false, "and says at the top that nothing has been run")
t.eq(doc.status, "theoretical", "and that everything in it is theoretical")
t.ok(doc.note:find("not evidence") ~= nil, "in words as well as in fields")
t.eq(#rejected, 0, "no candidate was turned away")
t.eq(#doc.edges, #gen.candidates, "every candidate is in the file")

t.eq(doc.provenance.command_display.ac_sha256, "753d02", "the catalogue checksum travels")
t.eq(doc.provenance.frame_data.commit, "a64f2ac", "so does the frame-data commit")
t.eq(doc.character, "zangief", "and the setup the file is about")
t.eq(doc.position, "midscreen", "including the position")

t.ok(doc.counts.total > 0, "counts are summarised")
t.ok(doc.counts.by_reason.frame_link ~= nil, "by reason")
t.ok(doc.counts.by_confidence ~= nil, "and by confidence")

-- --- attribution travels with the numbers ------------------------------------

t.group("attribution")

t.ok(doc.attribution ~= nil, "a document built from the frame data carries attribution")
t.eq(doc.attribution.license, "CC-BY-SA", "naming the licence")
t.eq(doc.attribution.commit, "a64f2ac", "and the exact commit")
t.ok(doc.attribution.license_url:find("by%-sa") ~= nil, "with a link to it")
t.ok(doc.attribution.share_alike:find("same licence") ~= nil,
     "and the ShareAlike obligation stated, since this is a derived work")
t.ok(doc.attribution.modifications:find("No source value was altered") ~= nil,
     "with the modifications named, which the licence also requires")

-- No frame data, no obligation - and no empty attribution block pretending
-- there is a source.
local noframes = Schema.provenance({
    game_patch = "x",
    command_display = { character = "Zangief", generated_at = "y", ac_sha256 = "z" },
})
local blind_gen = CG.generate(cat, nil, {
    from = { categories = { "normal" }, input_methods = { "manual" } },
    include_followups = false, provenance = noframes,
})
local blind_doc = Exporter.edges(blind_gen.candidates,
    { character = "zangief", provenance = noframes })
t.ok(blind_doc ~= nil, "a run with no frame data still exports")
t.is_nil(blind_doc.attribution, "and carries no attribution, because nothing was derived")

-- --- the header is required --------------------------------------------------

t.group("a document nobody can check is refused")

local nope, why = Exporter.edges(gen.candidates, { character = "zangief" })
t.is_nil(nope, "no provenance, no document")
t.ok(why.reason:find("worse than none") ~= nil, "and the refusal says why")

local nopatch = Exporter.edges(gen.candidates, { provenance = Schema.provenance({
    command_display = { character = "Z", generated_at = "y", ac_sha256 = "z" } }) })
t.is_nil(nopatch, "and without a game patch")

local nosum = Exporter.edges(gen.candidates, { provenance = Schema.provenance({
    game_patch = "p", command_display = { character = "Z", generated_at = "y" } }) })
t.is_nil(nosum, "and without a catalogue checksum, which is what tells two builds apart")

-- --- the gate ----------------------------------------------------------------

t.group("only candidates go in a candidate file")

local measured = {}
for k, v in pairs(gen.candidates[1]) do measured[k] = v end
measured.provenance = { game_patch = "p", calibration_id = "cal-1" }
Schema.transition(measured, Schema.STATUS.RUNTIME_PENDING)
Schema.transition(measured, Schema.STATUS.VERIFIED, { attempts = 3, successes = 3 })

local mixed = { measured }
for i = 2, 20 do mixed[#mixed + 1] = gen.candidates[i] end
local mdoc, mrejected = Exporter.edges(mixed, OPTS)
t.eq(#mdoc.edges, 19, "the measured record does not go in the candidate file")
t.eq(#mrejected, 1, "it is turned away")
t.eq(mrejected[1].reason, "not a candidate", "with the reason named")
t.eq(mrejected[1].id, measured.id, "and the record identified, so it can be filed properly")

-- A malformed record is turned away too, rather than travelling in a document
-- that vouches for it.
local broken = { schema = "ce.edge.v1", id = "broken", status = "theoretical",
                 runtime_verified = false, from = {}, to = {}, reasons = {},
                 requires_runtime_validation = {}, provenance = PROV }
local bdoc, brejected = Exporter.edges({ broken }, OPTS)
t.eq(#bdoc.edges, 0, "a malformed record does not get in")
t.eq(brejected[1].reason, "invalid record", "and the reason is that it is invalid")
t.ok(#brejected[1].problems > 0, "with the schema problems attached")

-- --- normalisation -----------------------------------------------------------

t.group("shared text is hoisted, not lost")

t.ok(#doc.runtime_unknowns > 0, "the standing unknowns are listed once at the top")
local shared = {}
for _, u in ipairs(doc.runtime_unknowns) do
    t.ok(type(u.why) == "string" and #u.why > 0, ("%s has an explanation"):format(u.key))
    shared[u.key] = u.why
end
t.ok(shared.pushback_range ~= nil, "including the ones on every candidate")
t.ok(shared.actual_input_timing ~= nil, "such as the input timing")

-- The per-record key list is untouched; only the duplicated prose is gone.
local e = doc.edges[1]
t.ok(#e.requires_runtime_validation >= 3, "a record still lists its own unknowns")
for _, u in ipairs(e.requires_runtime_validation) do
    t.ok(shared[u] ~= nil, ("unknown %s is explained in the header"):format(u))
end

t.eq(e.provenance_ref, "document", "records point at the document's provenance")
t.is_nil(e.provenance, "rather than carrying a thousand copies of it")
t.ok(doc.record_note:find("provenance_ref") ~= nil, "and the file explains the reference")

-- The caller's own records must come back untouched: a GraphStore holding the
-- same tables would otherwise find them quietly emptied by an export.
t.ok(gen.candidates[1].provenance ~= nil, "the caller's record keeps its provenance")
t.ok(gen.candidates[1].unknown_detail ~= nil, "and its explanations")

-- --- routes ------------------------------------------------------------------

t.group("routes")

local rdoc = Exporter.routes(routes, OPTS)
t.eq(rdoc.schema, "ce.candidate_routes.v1", "routes get their own schema tag")
t.eq(rdoc.runtime_verified, false, "and the same header promise")
t.eq(#rdoc.routes, #routes, "every route is in the file")
t.ok(rdoc.routes[1].offline_score ~= nil, "with its offline score")
t.is_nil(rdoc.routes[1].offline_score.damage, "which carries no measured-sounding damage")

local step = rdoc.routes[1].steps[1]
t.is_nil(step.delay_ticks, "and no step carries a delay, because none has been measured")

-- --- both at once ------------------------------------------------------------

t.group("the pair of documents")

local docs, rej = Exporter.documents({ edges = gen.candidates, routes = routes }, OPTS)
t.ok(docs ~= nil, "both documents build")
t.ok(docs["candidate-edges.json"] ~= nil, "named as the files they become")
t.ok(docs["candidate-routes.json"] ~= nil, "both of them")
t.eq(#rej.edges, 0, "with nothing turned away")
t.eq(#rej.routes, 0, "on either side")

local failed = Exporter.documents({ edges = gen.candidates, routes = routes },
                                  { character = "zangief" })
t.is_nil(failed, "and the pair fails together if the header is incomplete")

-- --- the licence travels with anything derived from the frame data -------------

t.group("attribution is public, because the candidate documents are not the only derived work")

-- docs/NOTICE.md: anything generated from data/frame-data is CC-BY-SA-4.0 and
-- so is anything derived from it in turn. The sweep worklist shipped without
-- this block - its `confidence`, and the order of the whole list, are computed
-- from these numbers - which is why the builder is no longer local.

do
    t.eq(type(Exporter.attribution_for), "function",
         "the builder is reachable from outside this module")

    local a = Exporter.attribution_for({
        source = "RyoSogawa/sf6-sensei", commit = "abc123",
        url = "https://example.invalid", license = "CC-BY-SA",
        fetched_at = "2026-09-10T09:58:49Z",
    })
    t.ok(a ~= nil, "it builds from a frame-data provenance block")
    t.eq(a.license, "CC-BY-SA", "carrying the licence")
    t.eq(a.commit, "abc123", "and the exact commit, so the version is checkable")
    t.ok(tostring(a.original_work):find("SuperCombo") ~= nil, "naming the original work")
    t.ok(tostring(a.license_url):find("creativecommons.org") ~= nil,
         "with the licence text reachable: " .. tostring(a.license_url))
    t.ok(tostring(a.share_alike):find("same licence") ~= nil,
         "and stating the ShareAlike obligation")

    -- The scope sentence matters: it is what tells a reader that a derived
    -- SCORE is covered, not only a copied number.
    t.ok(tostring(a.applies_to):find("derived") ~= nil,
         "and that it covers things derived from the numbers: " .. tostring(a.applies_to))

    t.is_nil(Exporter.attribution_for(nil),
             "with no frame data there is nothing to attribute")
end


return t.finish()
