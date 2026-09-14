-- =========================================================
-- tools/lua/labrows-cli.lua - trial logs in, NDJSON lab rows out.
--
--   lua tools/lua/labrows-cli.lua --trials <a.jsonl,b.jsonl,...>
--                                 [--routes <x.json,y.json,...>]
--
-- Paths are repo-relative and comma-separated (tools/db/lab-import.mjs passes
-- every committed file). Run from the repo root. Needs Lua 5.4; no game, no
-- network, no database.
-- =========================================================
--
-- One JSON object per line on stdout, each with a `kind`:
--
--   catalog           the catalog a character's pair notations were read from
--   route_definition  one ce.route.v1 file, with its shape
--   run               one trial line, as tools/lua/labrows.lua builds it
--   problem           a line that could not be turned into a row, and why
--   summary           counts, last
--
-- Nothing else is printed to stdout, so the importer can parse every line.
-- Diagnostics go to stderr. The exit status is 1 when any problem row was
-- written: every trial on disk is meant to import, so a refused line is a
-- failure to look at, not a count to skim past.
--
-- WHY THE PAIR INFORMATION COMES FROM A GENERATOR RUN, NOT A WORKLIST
--
-- The committed worklists are the pairs still worth sweeping, and 47 of the 216
-- framedata pairs have left them since (follow-ups after a move that is not
-- their parent, #49). The generator reports those as exclusions, with the
-- reason, so every pair in the logs is either a candidate with a mechanism or an
-- exclusion that says why - never silently absent.

local Cli      = dofile("tools/lua/cli.lua")
local json     = dofile("tools/lua/json.lua")
local Pipeline = dofile("tools/lua/pipeline.lua")
local LabRows  = dofile("tools/lua/labrows.lua")
local ResultCollector = require("func/ComboExplorer/core/ResultCollector")

local TOOL = "labrows-cli"
local opt = Cli.args(TOOL, arg, { trials = nil, routes = nil })
if type(opt.trials) ~= "string" or opt.trials == "" then
    Cli.die(TOOL, "--trials <a.jsonl,b.jsonl> is required")
end

local function split(s)
    local out = {}
    if type(s) ~= "string" then return out end
    for part in s:gmatch("[^,]+") do out[#out + 1] = part end
    return out
end

local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local text = f:read("a")
    f:close()
    return text
end

local function emit(row)
    io.stdout:write(json.encode(row), "\n")
end

local counts = { runs = 0, problems = 0, files = 0, routes = 0, truncated = 0, blank = 0 }

-- --- route definitions ---------------------------------------------------------

local route_defs = {}
for _, path in ipairs(split(opt.routes)) do
    local def = json.decode(read(path) or "")
    if type(def) ~= "table" or type(def.id) ~= "string" then
        counts.problems = counts.problems + 1
        emit({ kind = "problem", source_file = path, problems = { { field = "(file)",
               problem = "not a readable ce.route.v1" } } })
    else
        if route_defs[def.id] then
            -- Two files naming one id: whichever came last would silently define
            -- the route every legacy row resolves through.
            counts.problems = counts.problems + 1
            emit({ kind = "problem", source_file = path, problems = { { field = "id",
                   problem = ("route id %s is also defined in %s"):format(def.id, route_defs[def.id].path) } } })
        end
        route_defs[def.id] = { def = def, path = path }
        local steps = LabRows.definition_steps(def)
        local shape, why = LabRows.shape_key(steps)
        counts.routes = counts.routes + 1
        emit({ kind = "route_definition", source_file = path, definition_id = def.id,
               schema = def.schema, character = def.character, control_scheme = def.control_scheme,
               route = shape and { shape_key = shape, steps = steps } or nil,
               problem = (not shape) and why or nil })
    end
end

-- --- the catalog and generator, once per character and scheme ------------------------

local knowledge = {}
local function knowledge_for(character, scheme)
    local k = tostring(character) .. "|" .. tostring(scheme)
    if knowledge[k] ~= nil then return knowledge[k] or nil end
    local ctx, err = Pipeline.load({ character = character, scheme = scheme })
    if not ctx then
        io.stderr:write(("%s: no catalog for %s %s (%s) - pairs get no notation or mechanism\n")
            :format(TOOL, tostring(character), tostring(scheme), tostring(err)))
        knowledge[k] = false
        return nil
    end
    for _, w in ipairs(ctx.warnings or {}) do io.stderr:write(TOOL .. ": " .. w .. "\n") end
    local gen = Pipeline.generate(ctx, {})
    local pair = LabRows.pair_index(ctx.plain_edges, gen and gen.excluded, Pipeline.edge_pair_key)
    local notation = {}
    for _, row in ipairs(ctx.cat.rows) do
        notation[("%d:%s"):format(row.action_id, row.input_method)] = row.notation
    end
    emit({ kind = "catalog", character = character, control_scheme = scheme,
           ac_sha256 = ctx.meta.ac_sha256, bcm_sha256 = ctx.meta.bcm_sha256,
           generated_at = ctx.meta.generated_at, source_file = ctx.opt.catalog,
           frame_data = ctx.opt.frames, frame_data_loaded = ctx.idx ~= nil })
    knowledge[k] = { pair = pair, notation = notation }
    return knowledge[k]
end

local lookup = {
    pair = function(character, scheme, key)
        local kn = knowledge_for(character, scheme)
        return kn and kn.pair(key) or nil
    end,
    notation = function(character, scheme, id, method)
        local kn = knowledge_for(character, scheme)
        return kn and kn.notation[("%d:%s"):format(id, tostring(method))] or nil
    end,
    route = function(id)
        return route_defs[id] and route_defs[id].def or nil
    end,
}

-- --- the trial files ---------------------------------------------------------------

-- Every file is read before any row is built: superseded_rerun needs the
-- successor's keys, and supersedes needs the predecessor's.
local files, by_base = {}, {}
for _, path in ipairs(split(opt.trials)) do
    local text = read(path)
    if not text then Cli.die(TOOL, "could not read " .. path) end
    local lines, info = ResultCollector.scan(text)
    local file = { path = path, records = {}, bad = {} }
    for i, raw in ipairs(lines) do
        if i == #lines and info.unterminated then
            -- ResultCollector's rule: a line with no terminator is the tail of a
            -- trial whose result was lost, and is not believed even if it decodes.
            counts.truncated = counts.truncated + 1
            file.bad[#file.bad + 1] = { line_no = i, problems = { { field = "(line)",
                problem = "no terminator: a trial ran and its result was lost" } } }
        elseif raw:match("^%s*$") then
            counts.blank = counts.blank + 1
        else
            local rec, why = json.decode(raw)
            if type(rec) ~= "table" then
                file.bad[#file.bad + 1] = { line_no = i, problems = { { field = "(line)",
                    problem = "does not decode: " .. tostring(why) } } }
            else
                file.records[#file.records + 1] = { line_no = i, record = rec }
            end
        end
    end
    files[#files + 1] = file
    by_base[LabRows.basename(path)] = file
end

for _, file in ipairs(files) do
    counts.files = counts.files + 1
    local base = LabRows.basename(file.path)
    local rule = LabRows.FILES[base] or {}

    local successor
    if rule.superseded_by then
        local s = by_base[rule.superseded_by]
        if s then successor = LabRows.index_reruns(s.records)
        else
            io.stderr:write(("%s: %s is superseded by %s, which was not given - no row is flagged\n")
                :format(TOOL, base, rule.superseded_by))
        end
    end

    local predecessor
    for pbase, prule in pairs(LabRows.FILES) do
        if prule.superseded_by == base and by_base[pbase] then
            predecessor = { source_file = by_base[pbase].path,
                            index = LabRows.index_reruns(by_base[pbase].records) }
        end
    end

    for _, bad in ipairs(file.bad) do
        counts.problems = counts.problems + 1
        emit({ kind = "problem", source_file = file.path, line_no = bad.line_no, problems = bad.problems })
    end

    for _, r in ipairs(file.records) do
        local row, problems = LabRows.row(r.record, {
            source_file = file.path, line_no = r.line_no, lookup = lookup,
            successor = successor, predecessor = predecessor,
        })
        if row then
            counts.runs = counts.runs + 1
            emit(row)
        else
            counts.problems = counts.problems + 1
            emit({ kind = "problem", source_file = file.path, line_no = r.line_no, problems = problems })
        end
    end
end

emit({ kind = "summary", labrows_version = LabRows.VERSION, counts = counts })
os.exit(counts.problems == 0 and 0 or 1)
