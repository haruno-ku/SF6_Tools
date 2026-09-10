-- =========================================================
-- ComboExplorer/core/Exporter.lua - assembles the candidate documents.
-- Pure: records in, a plain table out. Encoding and writing belong to whoever
-- calls this - in the game that is JsonIO, on the dev machine the offline CLI.
-- =========================================================
--
-- WHAT THESE FILES ARE
--
-- Candidates. Every record in them is `theoretical`, the document says so at the
-- top, and the one thing this module will not do is let a row that claims to
-- have been verified travel in a file whose header says nothing has. Somebody
-- reading `candidate-routes.json` on another machine cannot ask what it means,
-- so the file has to say.
--
-- THE HEADER IS NOT DECORATION
--
-- An action id is meaningful only against one AC/BCM pair on one patch, and the
-- numbers behind the candidates came from one commit of one external source. A
-- file without those is not a weaker version of a file with them - it is a file
-- nobody can check, and the only safe thing to do with it later is throw it
-- away. So the provenance is required and export refuses without it.
--
-- ATTRIBUTION TRAVELS WITH THE NUMBERS
--
-- The frame data is CC-BY-SA-4.0 from the SuperCombo Wiki. Anything derived from
-- it carries the notice, which means these documents do whenever the frame
-- source contributed - and it contributed to every margin, every damage sum and
-- every confidence rating here.
--
-- SNAKE CASE THROUGHOUT
--
-- Including the header fields, so `runtime_verified` reads the same in the
-- document as it does in the records it contains. One spelling of one field is
-- worth more than matching an earlier sketch that used camelCase for two of
-- them.

local Schema = require("func/ComboExplorer/core/Schema")

local M = { name = "ComboExplorer.Exporter" }

M.KIND = {
    EDGES  = "ce.candidate_edges.v1",
    ROUTES = "ce.candidate_routes.v1",
}

-- The licence text that has to accompany anything derived from the frame
-- source. Filled from the frame_data provenance so it names the actual commit.
local function attribution_for(fd)
    if type(fd) ~= "table" then return nil end
    return {
        applies_to = "frame data: startup, on-hit, damage, cancel properties, "
            .. "and every candidate margin and score derived from them",
        original_work = "SuperCombo Wiki - Street Fighter 6 Frame Data",
        original_url = "https://wiki.supercombo.gg/w/Street_Fighter_6",
        obtained_via = fd.source,
        commit = fd.commit,
        source_url = fd.url,
        license = fd.license,
        license_url = (fd.license and tostring(fd.license):find("CC%-BY%-SA"))
            and "https://creativecommons.org/licenses/by-sa/4.0/" or nil,
        share_alike = "This document is a derived work of the above and is offered "
            .. "under the same licence.",
        modifications = "Joined to command_display action ids, filtered to the "
            .. "control scheme below, and combined into candidate edges and routes. "
            .. "No source value was altered.",
        fetched_at = fd.fetched_at,
    }
end

-- What the header has to have before a document may be written. Not a style
-- rule: without these the file cannot be checked against a later build, and an
-- unverifiable file is worse than no file.
local function check_provenance(p)
    local problems = {}
    if type(p) ~= "table" then
        return { { field = "provenance", problem = "required" } }
    end
    if p.game_patch == nil then
        problems[#problems + 1] = { field = "provenance.game_patch", problem = "required" }
    end
    local cd = p.command_display
    if type(cd) ~= "table" then
        problems[#problems + 1] = { field = "provenance.command_display", problem = "required" }
    else
        for _, f in ipairs({ "character", "generated_at" }) do
            if cd[f] == nil then
                problems[#problems + 1] = { field = "provenance.command_display." .. f,
                                            problem = "required" }
            end
        end
        if cd.ac_sha256 == nil and cd.bcm_sha256 == nil then
            -- One of the two is enough to pin the catalogue; neither is not.
            problems[#problems + 1] = {
                field = "provenance.command_display.ac_sha256",
                problem = "at least one catalogue checksum is required, so a later "
                    .. "build can be told apart from this one",
            }
        end
    end
    return problems
end

-- Collects the union of what only the game can settle, with one explanation
-- each, so a reader sees the standing list once instead of per record.
--
-- The explanations are long and nearly all identical - three of them are on
-- every single candidate - so the same text repeated across a thousand routes
-- is most of the file. Hoisting them here and dropping the copies is a
-- normalisation, not a trim: the per-record list of KEYS is untouched, and any
-- explanation that actually differs from the shared one stays on its record.
local function unknown_index(records)
    local index, order = {}, {}
    for _, r in ipairs(records) do
        for _, u in ipairs(r.requires_runtime_validation or {}) do
            if index[u] == nil then
                index[u] = (r.unknown_detail and r.unknown_detail[u]) or "see the record"
                order[#order + 1] = u
            end
        end
    end
    table.sort(order)
    local out = {}
    for _, u in ipairs(order) do out[#out + 1] = { key = u, why = index[u] } end
    return out, index
end

-- A copy of the record with the shared explanations removed. A copy, because
-- the caller's records belong to the caller - a GraphStore holding the same
-- tables must not find them quietly emptied by an export.
--
-- The provenance goes the same way and for the same reason: every record in a
-- document was generated in one run against one catalogue, so a thousand copies
-- of the same block is a thousand chances for one of them to be read as
-- different from the others. Records point at the header instead. Validation
-- runs BEFORE this, on the record as it came in, so nothing is exported that
-- did not have its own provenance to begin with.
local function hoisted(rec, shared)
    local copy = {}
    for k, v in pairs(rec) do copy[k] = v end

    if type(rec.unknown_detail) == "table" then
        local kept, any = {}, false
        for k, v in pairs(rec.unknown_detail) do
            if v ~= shared[k] then kept[k] = v any = true end
        end
        copy.unknown_detail = any and kept or nil
    end

    if rec.provenance ~= nil then
        copy.provenance = nil
        copy.provenance_ref = "document"
    end
    return copy
end

-- --- the gate ----------------------------------------------------------------

-- One record's fitness for a candidate document. Two ways to fail: not being a
-- valid record of its kind, and claiming a status the file does not describe.
local function admit(kind, rec)
    local ok, problems = Schema.validate(kind, rec)
    if not ok then
        return false, { id = rec and rec.id, reason = "invalid record", problems = problems }
    end
    if rec.status ~= Schema.STATUS.THEORETICAL then
        -- A measured row belongs in a results file, where its evidence and its
        -- calibration id travel with it. Putting it here would put a fact in a
        -- file headed "nothing here has been run".
        return false, { id = rec.id, reason = "not a candidate",
                        problems = { { field = "status",
                                       problem = ("status %s does not belong in a candidate document")
                                           :format(tostring(rec.status)) } } }
    end
    if rec.runtime_verified == true then
        return false, { id = rec.id, reason = "claims to have been run",
                        problems = { { field = "runtime_verified", problem = "must be false" } } }
    end
    return true
end

-- --- documents ---------------------------------------------------------------

local function build(kind, record_kind, field, records, opts)
    opts = opts or {}
    if type(records) ~= "table" then return nil, "no records" end

    local prov = opts.provenance
    local pproblems = check_provenance(prov)
    if #pproblems > 0 then
        return nil, { reason = "the document header is incomplete, and a document "
            .. "nobody can check against a later build is worse than none",
            problems = pproblems }
    end

    local kept, rejected = {}, {}
    local by_status, by_confidence, by_reason = {}, {}, {}
    for _, rec in ipairs(records) do
        local ok, why = admit(record_kind, rec)
        if ok then
            kept[#kept + 1] = rec
            by_status[rec.status] = (by_status[rec.status] or 0) + 1
            local c = rec.confidence or rec.min_confidence
            if c then by_confidence[c] = (by_confidence[c] or 0) + 1 end
            for _, r in ipairs(rec.reasons or {}) do
                by_reason[r] = (by_reason[r] or 0) + 1
            end
        else
            rejected[#rejected + 1] = why
        end
    end

    local doc = {
        schema = kind,
        -- Said at the top, in the same words the records use, so nobody has to
        -- read a record to learn what the file is.
        runtime_verified = false,
        status = Schema.STATUS.THEORETICAL,
        note = "Candidates. Nothing in this file has been run on Street Fighter 6. "
            .. "Every entry is a reason to spend a trial, not evidence that it works.",
        record_note = "Records carry provenance_ref = \"document\": the provenance "
            .. "block below applies to every record in this file, and a record lifted "
            .. "out of it has to take the block with it.",

        character = opts.character,
        control_scheme = opts.control_scheme,
        position = opts.position,
        counter = opts.counter,
        scope = opts.scope,

        generated_at = opts.generated_at,
        explorer_version = prov.explorer_version,
        provenance = prov,
        attribution = attribution_for(prov.frame_data),

        counts = {
            total = #kept,
            rejected = #rejected,
            by_status = by_status,
            by_confidence = by_confidence,
            by_reason = by_reason,
        },
        stats = opts.stats,
    }
    local unknowns, shared = unknown_index(kept)
    doc.runtime_unknowns = unknowns

    local records = {}
    for i, rec in ipairs(kept) do records[i] = hoisted(rec, shared) end
    doc[field] = records
    return doc, rejected
end

-- edges : candidate edges from CandidateGenerator (or a GraphStore's values)
function M.edges(edges, opts)
    return build(M.KIND.EDGES, Schema.KIND.EDGE, "edges", edges, opts)
end

-- routes : candidate routes from RouteSearch, scored or not
function M.routes(routes, opts)
    return build(M.KIND.ROUTES, Schema.KIND.ROUTE, "routes", routes, opts)
end

-- Everything the offline run produced, as the two documents plus whatever each
-- gate turned away. The rejected lists are returned rather than logged: a
-- record that did not make it into a file is exactly the thing somebody will
-- want to see.
function M.documents(result, opts)
    opts = opts or {}
    local edges_doc, edges_rejected = M.edges(result.edges or {}, opts)
    if not edges_doc then return nil, edges_rejected end
    local routes_doc, routes_rejected = M.routes(result.routes or {}, opts)
    if not routes_doc then return nil, routes_rejected end
    return {
        ["candidate-edges.json"] = edges_doc,
        ["candidate-routes.json"] = routes_doc,
    }, {
        edges = edges_rejected,
        routes = routes_rejected,
    }
end

return M
