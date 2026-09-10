-- =========================================================
-- tools/lua/explore.lua - the offline explorer. Runs the whole candidate
-- pipeline on a machine with no game on it.
--
--   lua tools/lua/explore.lua [options]
--
-- Reads command_display and the frame data, writes candidate-edges.json and
-- candidate-routes.json, and prints a report.
-- =========================================================
--
-- NOTHING THIS PRODUCES IS A COMBO
--
-- Every route in the output is a reason to spend a trial on the real game. The
-- documents say so, the records say so, and this script says so at the end of
-- its own report - because the one failure mode that matters here is somebody
-- reading a route list as a combo list.
--
-- WHY IT IS LUA AND NOT NODE
--
-- The pipeline modules are the ones that ship into the game, and they are
-- written for REFramework's Lua. Running them under the stock interpreter means
-- the offline output comes from the same code the runner will use, rather than
-- from a second implementation that agrees with it until it does not.

package.path = table.concat({ "./?.lua", "./?/init.lua", package.path }, ";")

-- REFramework resolves require("func/X/Y") relative to reframework/autorun.
-- Teaching the interpreter the same rule lets the shipped modules keep the
-- require paths they will actually run under.
table.insert(package.searchers, 2, function(name)
    if not name:match("^func/") then return nil end
    local path = "reframework/autorun/" .. name .. ".lua"
    local f = io.open(path, "r")
    if not f then return ("\n\tno file '%s'"):format(path) end
    f:close()
    local chunk, err = loadfile(path)
    if not chunk then return "\n\t" .. tostring(err) end
    return chunk, path
end)

local json      = dofile("tools/lua/json.lua")
local Catalog   = require("func/ComboExplorer/core/Catalog")
local FrameData = require("func/ComboExplorer/core/FrameData")
local CG        = require("func/ComboExplorer/core/CandidateGenerator")
local GraphStore = require("func/ComboExplorer/core/GraphStore")
local RouteSearch = require("func/ComboExplorer/core/RouteSearch")
local Scoring   = require("func/ComboExplorer/core/Scoring")
local Exporter  = require("func/ComboExplorer/core/Exporter")
local Schema    = require("func/ComboExplorer/core/Schema")

-- --- arguments ---------------------------------------------------------------

local function split(s)
    local out = {}
    for part in tostring(s):gmatch("[^,]+") do out[#out + 1] = part:match("^%s*(.-)%s*$") end
    return out
end

local opt = {
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
    top = 10,
    collapse = true,
}

local i = 1
while i <= #arg do
    local a = arg[i]
    local key = a:match("^%-%-([%w%-]+)$")
    if not key then
        io.stderr:write(("unrecognised argument %q\n"):format(a))
        os.exit(2)
    end
    key = key:gsub("%-", "_")
    if key == "no_collapse" then
        opt.collapse = false
        i = i + 1
    else
        local v = arg[i + 1]
        if v == nil then
            io.stderr:write(("--%s needs a value\n"):format(key))
            os.exit(2)
        end
        -- "false" is a non-empty string, and a non-empty string is truthy in
        -- Lua, so `--collapse false` used to turn collapsing ON and then record
        -- the string "false" in the exported document's copy of the search
        -- configuration - a file whose own account of the run said the opposite
        -- of what the run did.
        if v == "true" or v == "false" then
            opt[key] = (v == "true")
        else
            opt[key] = tonumber(v) or v
        end
        i = i + 2
    end
end

local char_lc = opt.character:lower()
opt.catalog = opt.catalog or
    ("reframework/data/TrainingComboTrials_data/command_display/%s.json"):format(opt.character)
opt.frames = opt.frames or ("data/frame-data/%s.lua"):format(char_lc)
opt.out = opt.out or ("candidates/%s/%s"):format(char_lc, opt.scheme)

-- --- inputs ------------------------------------------------------------------

local function die(msg)
    io.stderr:write("explore: " .. msg .. "\n")
    os.exit(1)
end

local raw, jerr = json.load_file(opt.catalog)
if not raw then die(("could not read %s: %s"):format(opt.catalog, tostring(jerr))) end

local cat, cat_problems = Catalog.build(raw)
if not cat then die("could not build a catalog from " .. opt.catalog) end

local frames_ok, frames_raw = pcall(dofile, opt.frames)
local idx
if frames_ok and frames_raw then
    idx = FrameData.index(frames_raw)
end
if not idx then
    -- Not fatal, and deliberately so: the generator treats absent numbers as
    -- unknown rather than as "cannot link", so a run with no frame data is a
    -- real, if blunter, run. It just has to be obvious that that is what
    -- happened.
    io.stderr:write(("explore: no frame data at %s - every candidate will be low "
        .. "confidence and nothing will be excluded on a margin\n"):format(opt.frames))
end

local meta = raw._meta or {}
local fmeta = idx and idx.meta or {}

-- The catalogue's generation date is not a game version, and calling it one
-- would be inventing a fact. It is named for what it is.
local provenance = Schema.provenance({
    game_patch = opt.game_patch or ("command_display@" .. tostring(meta.generated_at)),
    command_display = {
        character = meta.character,
        fighter_id = meta.fighter_id,
        generated_at = meta.generated_at,
        ac_sha256 = meta.ac_sha256,
        bcm_sha256 = meta.bcm_sha256,
        schema = meta.schema,
    },
    frame_data = idx and {
        source = fmeta.obtained_via or "RyoSogawa/sf6-sensei",
        commit = fmeta.commit,
        url = fmeta.source_url,
        license = fmeta.license,
        fetched_at = fmeta.fetched_at,
    } or nil,
    explorer_version = "offline-explorer-0.1.0",
    generated_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
})
provenance.game_patch_source =
    "the command_display generation date, not a confirmed game version - the real "
    .. "patch is only knowable on the machine running the game"

-- --- the pipeline ------------------------------------------------------------

local from_filter = { categories = split(opt.from_categories),
                      input_methods = split(opt.from_methods) }
local to_filter   = { categories = split(opt.to_categories),
                      input_methods = split(opt.to_methods) }

local gen = CG.generate(cat, idx, {
    from = from_filter,
    to = to_filter,
    include_followups = true,
    provenance = provenance,
})
if not gen then die("candidate generation produced nothing") end

local identity = {
    character = char_lc,
    game_patch = provenance.game_patch,
    ac_sha256 = meta.ac_sha256,
    bcm_sha256 = meta.bcm_sha256,
}
local graph = GraphStore.build(gen.candidates, identity)

local found = RouteSearch.search(graph, {
    frame_idx = idx,
    character = char_lc,
    control_scheme = opt.scheme,
    position = opt.position,
    counter = opt.counter,
    max_steps = opt.max_steps,
    beam_width = opt.beam,
    max_routes = opt.max_routes,
    collapse_canonical_variants = opt.collapse,
    provenance = provenance,
})
local routes = Scoring.apply(found.routes)

-- --- documents ---------------------------------------------------------------

local export_opts = {
    character = char_lc,
    control_scheme = opt.scheme,
    position = opt.position,
    counter = opt.counter,
    scope = {
        from = from_filter, to = to_filter,
        include_followups = true,
        search = found.config,
    },
    generated_at = provenance.generated_at,
    provenance = provenance,
    stats = { generation = gen.stats, search = found.stats,
              scoring = Scoring.summary(routes) },
}

local docs, rejected = Exporter.documents({ edges = gen.candidates, routes = routes },
                                          export_opts)
if not docs then
    die("export refused: " .. tostring(rejected and rejected.reason))
end

local function mkdir(path)
    -- No lfs under the stock interpreter, so the platform's own tool does it.
    local cmd = (package.config:sub(1, 1) == "\\")
        and ('cmd /c if not exist "%s" mkdir "%s" >nul 2>&1'):format(path:gsub("/", "\\"),
                                                                     path:gsub("/", "\\"))
        or ('mkdir -p "%s"'):format(path)
    os.execute(cmd)
end
mkdir(opt.out)

local written = {}
for name, doc in pairs(docs) do
    local path = opt.out .. "/" .. name
    local n, werr = json.save_file(path, doc, { indent = "  " })
    if not n then die(("could not write %s: %s"):format(path, tostring(werr))) end
    written[#written + 1] = { path = path, bytes = n }
end
table.sort(written, function(a, b) return a.path < b.path end)

-- --- the report --------------------------------------------------------------

local out = {}
local function say(fmt, ...)
    local line = select("#", ...) > 0 and fmt:format(...) or fmt
    out[#out + 1] = line
    print(line)
end

say("# Offline candidate report - %s / %s / %s / %s",
    opt.character, opt.scheme, opt.position, opt.counter)
say("")
say("EVERYTHING BELOW IS A THEORETICAL CANDIDATE. Nothing here has been run on")
say("Street Fighter 6. These are pairs and sequences worth spending a trial on,")
say("not combos that are known to work.")
say("")
say("## Provenance")
say("")
say("- command_display: %s, generated %s", tostring(meta.character), tostring(meta.generated_at))
say("  - ac_sha256  %s", tostring(meta.ac_sha256))
say("  - bcm_sha256 %s", tostring(meta.bcm_sha256))
if idx then
    say("- frame data: %s @ %s (%s)", tostring(fmeta.obtained_via),
        tostring(fmeta.commit), tostring(fmeta.license))
    say("  - original work: SuperCombo Wiki, CC-BY-SA-4.0. See docs/NOTICE.md.")
else
    say("- frame data: NONE. Every candidate is low confidence.")
end
say("- game patch: %s", tostring(provenance.game_patch))
say("  (%s)", provenance.game_patch_source)
say("")

say("## Moves searched")
say("")
local probeable = Catalog.probeable(cat, from_filter)
local targets = Catalog.probeable(cat, to_filter)
say("- catalog rows            %d", #cat.rows)
say("- starting moves          %d  (%s / %s)", #probeable,
    opt.from_categories, opt.from_methods)
say("- target moves            %d  (%s / %s)", #targets,
    opt.to_categories, opt.to_methods)
say("- excluded from probing   %d  (classic-only, air, throws, system, follow-ups)",
    cat.counts.excluded)
if idx then
    local cov = FrameData.coverage(idx, probeable)
    say("- frame data coverage     %d of %d (%.0f%%)", cov.matched, cov.rows, cov.ratio * 100)
    if cov.unmatched > 0 then
        for _, u in ipairs(cov.unmatched_detail) do
            say("    no frame data for %s (%s)", tostring(u.classic), tostring(u.action_id))
        end
    end
end
-- Several moves share one notation and the data cannot say which action id the
-- button produces. Carried through the whole pipeline rather than resolved by
-- picking one, because the game resolves it in Phase 1.
say("- unresolved canonical ids %d groups covering %d rows",
    cat.counts.ambiguous_groups, cat.counts.ambiguous_rows)
-- Not the same thing as an excluded row: these entries produce no row at all,
-- because the source gives them no Modern input to press.
say("- no Modern form at all     %d", cat.counts.unreachable)
for _, u in ipairs(cat.unreachable) do
    say("    %d  %s", u.action_id, tostring(u.classic))
end
say("")

say("## Theoretical edges")
say("")
say("- pairs considered        %d", gen.stats.pairs_considered)
say("- candidate edges         %d", #gen.candidates)
say("- excluded                %d", #gen.excluded)
say("")
say("by reason:")
local keys = {}
for k in pairs(gen.stats.by_reason) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do say("  %-24s %d", k, gen.stats.by_reason[k]) end
say("")
say("by confidence:")
for _, k in ipairs({ "high", "medium", "low" }) do
    say("  %-24s %d", k, gen.stats.by_confidence[k] or 0)
end
say("")
say("excluded because the numbers said no:")
keys = {}
for k in pairs(gen.stats.by_exclusion) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do say("  %-24s %d", k, gen.stats.by_exclusion[k]) end
say("")
say("Nothing was excluded for missing data. A gap in the source is recorded as")
say("an unknown and the pair stays a candidate; only a KNOWN negative margin")
say("excludes, and the margin is kept with it.")
say("")

say("## Route candidates")
say("")
say("- routes                  %d", #routes)
say("- graph nodes             %d", GraphStore.node_count(graph))
say("- graph edges             %d", GraphStore.edge_count(graph))
if found.stats.collapsed_variants then
    say("- folded canonical variants %d  (same buttons, unresolved action id)",
        found.stats.collapsed_variants)
end
say("- search complete         %s", tostring(found.stats.complete))
if not found.stats.complete then
    say("  beam dropped %d partial routes, %d routes not emitted",
        found.stats.beam_dropped_total, found.stats.truncated_routes)
end
keys = {}
for k in pairs(found.stats.by_length) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do say("  length %d               %d", k, found.stats.by_length[k]) end
say("")
say("dropped by a search bound (not by the game):")
keys = {}
for k in pairs(found.stats.pruned) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do say("  %-24s %d", k, found.stats.pruned[k]) end
say("")

local function render(route)
    local parts = {}
    for _, s in ipairs(route.steps) do
        parts[#parts + 1] = tostring(s.notation or s.classic)
    end
    return table.concat(parts, " > ")
end

say("## Top %d by predicted damage", opt.top)
say("")
say("Predicted damage is an UNSCALED frame-table sum. Combo scaling appears in no")
say("frame table and neither does Modern's own damage reduction, so this is an")
say("upper bound for ordering, never a damage figure.")
say("")
say("%-3s %-44s %8s %6s %-7s %s", "#", "route", "dmg~", "cost", "conf", "unknowns")
for n, route in ipairs(Scoring.rank(routes, Scoring.AXES.DAMAGE, opt.top)) do
    local s = route.offline_score
    say("%-3d %-44s %8d %6.1f %-7s %d", n, render(route),
        s.predicted_damage or 0, s.execution_cost, s.theoretical_confidence or "?",
        #(route.requires_runtime_validation or {}))
end
say("")

say("## Top %d by fewest inputs", opt.top)
say("")
say("%-3s %-44s %8s %6s %-7s", "#", "route", "dmg~", "cost", "conf")
for n, route in ipairs(Scoring.rank(routes, Scoring.AXES.SIMPLICITY, opt.top)) do
    local s = route.offline_score
    say("%-3d %-44s %8d %6.1f %-7s", n, render(route),
        s.predicted_damage or 0, s.execution_cost, s.theoretical_confidence or "?")
end
say("")

local front = Scoring.pareto(routes)
say("## Pareto frontier: %d routes nothing beats on both damage and inputs", #front)
say("")
for n = 1, math.min(opt.top, #front) do
    local s = front[n].offline_score
    say("%-3d %-44s %8d %6.1f", n, render(front[n]), s.predicted_damage or 0, s.execution_cost)
end
say("")

say("## Why the game still has to answer")
say("")
local doc = docs["candidate-routes.json"]
for _, u in ipairs(doc.runtime_unknowns) do
    say("- **%s**", u.key)
    say("  %s", u.why)
end
say("")
say("Three of these apply to every candidate without exception: pushback and")
say("range, Modern-specific damage scaling, and the actual input timing. No")
say("frame table contains any of them, which is why no edge in this file is")
say("marked as decidable offline.")
say("")

if rejected and (#rejected.edges > 0 or #rejected.routes > 0) then
    say("## Records the export turned away")
    say("")
    say("- edges  %d", #rejected.edges)
    say("- routes %d", #rejected.routes)
    for n = 1, math.min(5, #rejected.edges) do
        say("  edge %s: %s", tostring(rejected.edges[n].id), rejected.edges[n].reason)
    end
    for n = 1, math.min(5, #rejected.routes) do
        say("  route %s: %s", tostring(rejected.routes[n].id), rejected.routes[n].reason)
    end
    say("")
end

if #cat_problems > 0 then
    say("## Catalog entries the classifier could not place: %d", #cat_problems)
    say("")
    for n = 1, math.min(10, #cat_problems) do
        local p = cat_problems[n]
        say("  %s  %s", tostring(p.action_id), tostring(p.reason))
    end
    say("")
end

say("## Written")
say("")
for _, w in ipairs(written) do say("- %s  (%d bytes)", w.path, w.bytes) end
say("")
say("Both documents carry runtime_verified = false and every record in them is")
say("status = theoretical. The next step is the gaming machine: calibration,")
say("then a sweep, then these become confirmed edges or rejected ones.")

local rf = io.open(opt.out .. "/report.md", "wb")
if rf then
    rf:write(table.concat(out, "\n"))
    rf:write("\n")
    rf:close()
end
