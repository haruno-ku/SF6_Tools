-- =========================================================
-- tools/lua/pipeline.lua - the offline candidate pipeline as a library:
-- catalog and frame data in, scored routes and worklist records out.
-- Dev-machine only, like the rest of tools/.
-- =========================================================
--
-- WHY THIS EXISTS
--
-- explore.lua runs the whole pipeline top to bottom as one script: arguments,
-- catalog, frame data, provenance, generation, graph, search, scoring, the
-- documents and the worklist. plan.lua needs every step of that up to the
-- scored routes, and the worklist writer after it, and a planner whose routes
-- came from a second copy of that script would be planning over routes that
-- agree with explore's until the day one of them is edited.
--
-- So the steps live here, and plan.lua calls them. explore.lua does not yet -
-- it still carries its own copy of every function below, and can switch to
-- this module in a change of its own. Until it does, the two copies are named
-- at each function so a fix to one is a reminder to fix the other.
--
-- The settings are explore's defaults, copied as they are, so a plan run with
-- no conditions ranks the same 917 Zangief routes explore's report lists.

dofile("tools/lua/cli.lua")   -- the require shim, installed once

local json       = dofile("tools/lua/json.lua")
local Characters = dofile("tools/lua/characters.lua")
local Catalog    = require("func/ComboExplorer/core/Catalog")
local FrameData  = require("func/ComboExplorer/core/FrameData")
local CG         = require("func/ComboExplorer/core/CandidateGenerator")
local GraphStore = require("func/ComboExplorer/core/GraphStore")
local RouteSearch = require("func/ComboExplorer/core/RouteSearch")
local Scoring    = require("func/ComboExplorer/core/Scoring")
local Exporter   = require("func/ComboExplorer/core/Exporter")
local Schema     = require("func/ComboExplorer/core/Schema")

local M = { name = "tools.pipeline" }

-- explore.lua's `opt` defaults, less the report's own `top`.
M.DEFAULTS = {
    character = "Zangief",
    scheme = "modern",
    position = "midscreen",
    counter = "none",
    from_categories = "normal,command_normal",
    to_categories = "normal,command_normal,special,od_special,super",
    from_methods = "manual",
    to_methods = "manual,simple",
    max_steps = 3,
    beam = 4000,
    max_routes = 20000,
    collapse = true,
}

M.WL_DIR = "reframework/data/ComboExplorer_data/worklist"
M.DATA_DIR = "reframework/data/ComboExplorer_data"

function M.split(s)
    local out = {}
    for part in tostring(s):gmatch("[^,]+") do out[#out + 1] = part:match("^%s*(.-)%s*$") end
    return out
end

-- --- inputs ----------------------------------------------------------------------

-- Everything the pipeline reads, and the provenance it stamps on what it
-- writes. explore.lua's "inputs" section, as a function.
--
-- opt : M.DEFAULTS overridden by the caller. Returns ctx, or nil and a reason.
-- ctx.warnings lists what was missing but not fatal - today only the frame
-- data, whose absence makes every candidate low confidence.
function M.load(opt)
    local o = {}
    for k, v in pairs(M.DEFAULTS) do o[k] = v end
    for k, v in pairs(opt or {}) do o[k] = v end

    local entry, cerr = Characters.resolve(o.character)
    if not entry then return nil, tostring(cerr) end
    o.character = entry.catalog
    local char_lc = entry.catalog:lower()
    o.catalog = o.catalog or Characters.catalog_path(entry)
    o.frames = o.frames or Characters.frame_data_path(entry)

    local raw, jerr = json.load_file(o.catalog)
    if not raw then return nil, ("could not read %s: %s"):format(o.catalog, tostring(jerr)) end
    local cat, cat_problems = Catalog.build(raw)
    if not cat then return nil, "could not build a catalog from " .. o.catalog end

    local warnings = {}
    local frames_ok, frames_raw = pcall(dofile, o.frames)
    local idx
    if frames_ok and frames_raw then idx = FrameData.index(frames_raw) end
    if not idx then
        warnings[#warnings + 1] = ("no frame data at %s - every candidate will be low "
            .. "confidence and nothing will be excluded on a margin"):format(o.frames)
    end

    local meta = raw._meta or {}
    local fmeta = idx and idx.meta or {}
    local provenance = Schema.provenance({
        game_patch = o.game_patch or ("command_display@" .. tostring(meta.generated_at)),
        command_display = {
            character = meta.character, fighter_id = meta.fighter_id,
            generated_at = meta.generated_at, ac_sha256 = meta.ac_sha256,
            bcm_sha256 = meta.bcm_sha256, schema = meta.schema,
        },
        frame_data = idx and {
            source = fmeta.obtained_via or "RyoSogawa/sf6-sensei",
            commit = fmeta.commit, url = fmeta.source_url,
            license = fmeta.license, fetched_at = fmeta.fetched_at,
        } or nil,
        explorer_version = "offline-explorer-0.1.0",
        generated_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    })
    provenance.game_patch_source =
        "the command_display generation date, not a confirmed game version - the real "
        .. "patch is only knowable on the machine running the game"

    return {
        opt = o, entry = entry, char_lc = char_lc,
        raw = raw, cat = cat, cat_problems = cat_problems,
        idx = idx, meta = meta, fmeta = fmeta, provenance = provenance,
        warnings = warnings,
        identity = { character = char_lc, game_patch = provenance.game_patch,
                     ac_sha256 = meta.ac_sha256, bcm_sha256 = meta.bcm_sha256 },
    }
end

-- --- generation and search ----------------------------------------------------------

-- Candidate edges, split into plain and Drive Rush Cancel, as explore.lua
-- splits them. opts.drive_rush generates the DRC ones at all.
function M.generate(ctx, opts)
    opts = opts or {}
    local o = ctx.opt
    ctx.from_filter = { categories = M.split(o.from_categories), input_methods = M.split(o.from_methods) }
    ctx.to_filter = { categories = M.split(o.to_categories), input_methods = M.split(o.to_methods) }
    local gen = CG.generate(ctx.cat, ctx.idx, {
        from = ctx.from_filter, to = ctx.to_filter,
        include_followups = true,
        include_drive_rush = opts.drive_rush == true,
        provenance = ctx.provenance,
    })
    if not gen then return nil, "candidate generation produced nothing" end
    local plain, drc = {}, {}
    for _, e in ipairs(gen.candidates) do
        if CG.is_drive_rush(e) then drc[#drc + 1] = e else plain[#plain + 1] = e end
    end
    ctx.gen, ctx.plain_edges, ctx.drc_edges = gen, plain, drc
    return gen
end

-- The graph, the search and the scores.
--
-- explore.lua puts only the plain edges into the graph: its documents predate
-- route steps for a rush. opts.drive_rush puts the DRC edges in as well, which
-- RouteSearch turns into `{ kind = "drive_rush_cancel" }` steps. Without it the
-- routes are explore's routes.
--
-- opts.max_steps widens the search beyond explore's 3 when a condition asks
-- for longer routes than that; the caller reports that it did.
function M.search(ctx, opts)
    opts = opts or {}
    local o = ctx.opt
    local edges = {}
    for _, e in ipairs(ctx.plain_edges) do edges[#edges + 1] = e end
    if opts.drive_rush then
        for _, e in ipairs(ctx.drc_edges) do edges[#edges + 1] = e end
    end
    local graph = GraphStore.build(edges, ctx.identity)
    local found = RouteSearch.search(graph, {
        frame_idx = ctx.idx,
        character = ctx.char_lc,
        control_scheme = o.scheme,
        position = o.position,
        counter = o.counter,
        max_steps = opts.max_steps or o.max_steps,
        beam_width = o.beam,
        max_routes = o.max_routes,
        collapse_canonical_variants = o.collapse,
        provenance = ctx.provenance,
    })
    ctx.graph, ctx.found = graph, found
    ctx.routes = Scoring.apply(found.routes)
    return ctx.routes, found
end

-- --- pairs and worklist records --------------------------------------------------------

-- runtime/Sweep.lua's pair_key, over a candidate edge.
function M.edge_pair_key(e)
    local a, b = e.from, e.to
    if CG.is_drive_rush(e) then
        return ("%d:%s->drc->%d:%s"):format(a.action_id, tostring(a.input_method),
                                            b.action_id, tostring(b.input_method))
    end
    return ("%d:%s->%d:%s"):format(a.action_id, tostring(a.input_method),
                                   b.action_id, tostring(b.input_method))
end

-- Every candidate edge by pair key and by edge id. A key two edges share is
-- listed in `duplicates` rather than resolved by whichever came last.
function M.edge_index(ctx)
    local by_key, by_id, duplicates = {}, {}, {}
    for _, list in ipairs({ ctx.plain_edges or {}, ctx.drc_edges or {} }) do
        for _, e in ipairs(list) do
            local k = M.edge_pair_key(e)
            if by_key[k] then duplicates[#duplicates + 1] = k else by_key[k] = e end
            if e.id then by_id[e.id] = e end
        end
    end
    return { by_key = by_key, by_id = by_id, duplicates = duplicates }
end

-- One worklist record for one candidate edge: the fields explore.lua writes
-- for it, plain or Drive Rush Cancel.
--
-- A COPY. explore.lua builds the same two records inline, in its "the sweep
-- worklist" and "Drive Rush Cancel candidates" sections, and the reasons for
-- every field are written there: the frames rather than a computed gap (#46),
-- context_known as a vouch the runtime reads (#49), no plain margin on a DRC
-- pair. Change one and change the other, until explore.lua calls this.
function M.worklist_item(e)
    local b = e.basis or {}
    if CG.is_drive_rush(e) then
        return {
            a_id = e.from.action_id, a_method = e.from.input_method,
            a_notation = e.from.notation,
            b_id = e.to.action_id, b_method = e.to.input_method,
            b_notation = e.to.notation,
            confidence = e.confidence,
            via = e.via,
            a_startup = b.from_startup,
            a_active = b.from_active,
            a_recovery = b.from_recovery,
            a_hitstop = b.from_hitstop,
            a_hitstun = b.from_hitstun,
            a_on_hit = b.from_on_hit,
            a_drc_on_hit = b.from_drc_on_hit,
            b_startup = b.to_startup,
            drc_margin_frames = b.drc_margin_frames,
            drive_cost = b.drive_cost,
        }
    end
    return {
        a_id = e.from.action_id, a_method = e.from.input_method,
        a_notation = e.from.notation,
        b_id = e.to.action_id, b_method = e.to.input_method,
        b_notation = e.to.notation,
        confidence = e.confidence,
        a_startup = b.from_startup,
        a_active = b.from_active,
        a_recovery = b.from_recovery,
        a_hitstop = b.from_hitstop,
        a_hitstun = b.from_hitstun,
        a_on_hit = b.from_on_hit,
        b_startup = b.to_startup,
        margin_frames = b.margin_frames,
        mechanism = CG.mechanism(e),
        context_dependent = e.context_dependent or nil,
        context_known = e.context_known or nil,
    }
end

-- explore.lua's worklist_order, for a caller that wants the confidence order.
-- plan.lua does not: its order is the plan's.
local RANK = { high = 3, medium = 2, low = 1 }
function M.worklist_order(x, y)
    local rx, ry = RANK[x.confidence] or 0, RANK[y.confidence] or 0
    if rx ~= ry then return rx > ry end
    if x.a_id ~= y.a_id then return x.a_id < y.a_id end
    if x.b_id ~= y.b_id then return x.b_id < y.b_id end
    if x.a_method ~= y.a_method then return tostring(x.a_method) < tostring(y.a_method) end
    return tostring(x.b_method) < tostring(y.b_method)
end

-- The ce.worklist.v1 envelope, as explore.lua's write_worklist builds it: the
-- identity hashes, the patch, and the attribution block. `items` is written in
-- the order given. extra fields are copied on top.
--
-- Refused without attribution when frame data was used, for explore's reason:
-- the confidence on every pair, and here the route ranks that chose them, are
-- derived from the frame data, which docs/NOTICE.md makes CC-BY-SA-4.0.
function M.worklist_doc(ctx, items, extra)
    local doc = {
        schema = "ce.worklist.v1",
        character = ctx.opt.character,
        control_scheme = ctx.opt.scheme,
        ac_sha256 = ctx.meta.ac_sha256,
        bcm_sha256 = ctx.meta.bcm_sha256,
        generated_at = ctx.provenance.generated_at,
        game_patch = ctx.provenance.game_patch,
        count = #items,
        pairs = items,
        attribution = Exporter.attribution_for(ctx.provenance.frame_data),
    }
    for k, v in pairs(extra or {}) do doc[k] = v end
    if ctx.idx and type(doc.attribution) ~= "table" then
        return nil, "refusing to write a worklist with no attribution: its confidence and "
            .. "its ordering are derived from the frame data, which is CC-BY-SA-4.0"
    end
    return doc
end

-- --- what the game has already said -------------------------------------------------------

-- One JSONL log. A line that will not decode is counted, not dropped: it is a
-- trial that ran and whose result was lost (report.lua and confirm.lua hold the
-- same rule).
function M.read_log(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local text = f:read("a")
    f:close()
    local records, bad = {}, 0
    for line in text:gmatch("[^\r\n]+") do
        local ok, rec = pcall(json.decode, line)
        if ok and type(rec) == "table" then records[#records + 1] = rec else bad = bad + 1 end
    end
    return records, bad
end

-- Every trial log for the character, as report.lua gathers them.
function M.load_logs(data_dir, char_lc, list_dir)
    local logs = {}
    local prefix = char_lc .. "-"
    for _, name in ipairs(list_dir(data_dir .. "/trials")) do
        if name:sub(1, #prefix) == prefix and name:match("%.jsonl$") then
            local path = ("%s/trials/%s"):format(data_dir, name)
            local records, bad = M.read_log(path)
            if records then
                logs[#logs + 1] = { name = (name:gsub("%.jsonl$", "")), path = path,
                                    records = records, bad_lines = bad }
            end
        end
    end
    return logs
end

function M.load_route_defs(data_dir, list_dir)
    local routes = {}
    for _, name in ipairs(list_dir(data_dir .. "/route")) do
        if name:match("%.json$") then
            local doc = json.load_file(("%s/route/%s"):format(data_dir, name))
            if type(doc) == "table" and doc.id then routes[doc.id] = doc end
        end
    end
    return routes
end

-- Classic notation by action id, from the catalog already read.
function M.classic_by_id(raw)
    local classic = {}
    for id, row in pairs(raw or {}) do
        local cc = type(row) == "table" and row.classic_command
        if type(cc) == "table" and type(cc.display) == "string" then
            classic[tonumber(id) or id] = cc.display
        end
    end
    return classic
end

return M
