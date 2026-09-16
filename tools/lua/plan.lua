-- =========================================================
-- tools/lua/plan.lua - state the conditions first, then sweep only the pairs
-- the routes that satisfy them need.
--
--   lua tools/lua/plan.lua --character Zangief [--scheme modern]
--       [--starter-button 中 | --starter-buttons L,M
--        | --starter-notation "2 + 中" | --starter-id 604]
--       [--starter-neutral] [--input-method manual|simple|assist]
--       [--first-pair-mechanism cancel,both] [--max-execution-cost N]
--       [--no-gauge] [--no-super] [--no-drive-rush] [--max-drive-bars N]
--       [--min-steps N] [--max-steps N] [--min-confidence low|medium|high]
--       [--sort scaled_damage|damage|simple|confidence] [--top 20]
--       [--name <plan name>] [--drive-rush] [--include-verified]
--       [--no-demote-rejected] [--routes N]
--       [--search-steps N] [--beam N]
--
-- Needs Lua 5.4, the catalog and the frame data. Reads the committed trial logs
-- if there are any. No game, no network.
-- =========================================================
--
-- WHY CONDITIONS FIRST
--
-- The worklist explore.lua writes is every candidate pair - 324 for Zangief
-- Modern - in confidence order. A sweep of it answers "what connects", and it
-- is a long way round to "what is the most damaging combo that spends no
-- gauge". The routes that satisfy a condition are a handful of pairs each, and
-- the best twenty share most of them, so this runs the same pipeline, keeps the
-- routes that satisfy the conditions, and writes a worklist of only the pairs
-- those routes need, in the order of the routes that need them.
--
-- WHAT IT WRITES
--
--   docs/ComboExplorer/plans/<char>-<scheme>-<name>.md
--       the report: conditions, what each filter removed, the top routes, the
--       pairs to sweep and the ones the logs already answer
--   reframework/data/ComboExplorer_data/worklist/<char>-<scheme>-plan-<name>.json
--       ce.worklist.v1 with only the needed pairs, in route-rank order, each
--       with explore's per-pair fields plus needed_by_ranks and known_status
--   reframework/data/ComboExplorer_data/route/<char>-<scheme>-<name>-<rank>.json
--       with --routes N: the plan's best N routes as ce.route.v1, each gap at
--       the delays the logs measured for that pair, or the grid the sweep would
--       predict, never one invented number (tools/lua/routefile.lua)
--
-- WHICH ANSWERS IT BELIEVES
--
-- A pair's status comes from tools/lua/labeval.lua's policy ce-eval-v1, the one
-- the lab database applies, over rows built here by tools/lua/labrows.lua: a
-- negative counts only when the run asked the question at a pressable input and
-- the right timing. So `rejected` means a conclusive no, and only a conclusive
-- no demotes a route. A pair whose every negative the policy threw out is
-- `asked_badly` - a question nobody has asked yet - and is asked, not demoted.
--
-- NOTHING THIS PRODUCES IS A COMBO, for explore.lua's reason. A route in a plan
-- is a reason to spend trials on the game, ranked by a prediction.

local Cli = dofile("tools/lua/cli.lua")

local json        = dofile("tools/lua/json.lua")
local Pipeline    = dofile("tools/lua/pipeline.lua")
local Planner     = dofile("tools/lua/planner.lua")
local SweepReport = dofile("tools/lua/sweepreport.lua")
local LabKnown    = dofile("tools/lua/labknown.lua")
local LabRows     = dofile("tools/lua/labrows.lua")
local RouteFile   = dofile("tools/lua/routefile.lua")
local CG          = require("func/ComboExplorer/core/CandidateGenerator")
local ConfirmedEdge = require("func/ComboExplorer/core/ConfirmedEdge")
local RouteSearch = require("func/ComboExplorer/core/RouteSearch")
local Route       = require("func/ComboExplorer/core/Route")
local Provenance  = require("func/ComboExplorer/core/Provenance")
local Sweep       = require("func/ComboExplorer/runtime/Sweep")

local TOOL = "plan"

-- --- arguments ---------------------------------------------------------------

local defaults = {}
for k, v in pairs(Pipeline.DEFAULTS) do defaults[k] = v end
defaults.sort = "scaled_damage"
defaults.top = 20
defaults.demote_rejected = true
defaults.include_verified = false
defaults.drive_rush = false
defaults.data = Pipeline.DATA_DIR
defaults.routes = 0

-- Pipeline.DEFAULTS.max_steps is the SEARCH depth. The condition of the same
-- name is read before the defaults are merged, so an unset condition stays
-- unset rather than becoming "at most 3" and appearing in the plan's name.
local argv = Planner.normalize_argv(arg)
local given = Cli.args(TOOL, argv, {})
local opt = Cli.args(TOOL, argv, defaults)
opt.max_steps = Pipeline.DEFAULTS.max_steps
local cond_opt = {}
for k, v in pairs(given) do cond_opt[k] = v end

local cond = Planner.conditions_from(cond_opt)
local exclusive = 0
for _, k in ipairs({ "starter_button", "starter_buttons", "starter_notation", "starter_id" }) do
    if cond[k] ~= nil then exclusive = exclusive + 1 end
end
if exclusive > 1 then
    Cli.die(TOOL, "give one of --starter-button, --starter-buttons, --starter-notation and "
        .. "--starter-id, not several")
end
if not Planner.SORTS[opt.sort] then
    Cli.die(TOOL, ("--sort must be scaled_damage, damage, simple or confidence, not %q")
        :format(tostring(opt.sort)))
end
local top = tonumber(opt.top)
if not top or top < 1 then Cli.die(TOOL, "--top must be a positive number") end
local want_routes = tonumber(opt.routes) or 0
if want_routes < 0 then Cli.die(TOOL, "--routes must be zero or more") end

-- --- the pipeline ------------------------------------------------------------

local search_opt = {}
for k, v in pairs(opt) do
    if Pipeline.DEFAULTS[k] ~= nil then search_opt[k] = v end
end
local ctx, lerr = Pipeline.load(search_opt)
if not ctx then Cli.die(TOOL, lerr) end
for _, w in ipairs(ctx.warnings) do io.stderr:write(TOOL .. ": " .. w .. "\n") end

local gen, gerr = Pipeline.generate(ctx, { drive_rush = opt.drive_rush == true })
if not gen then Cli.die(TOOL, gerr) end

-- How deep the search itself goes, before any condition widens it.
--
-- `--max-steps` is a CONDITION (line 88 puts the search depth back), so a caller
-- that wants explore's own depth changed needs a key of its own: --search-steps.
-- tools/lua/all.lua passes it, with a bigger --beam, for the priority character,
-- whose search is otherwise cut short by the beam (see Batch.DEEP).
local base_depth = tonumber(opt.search_steps)
if opt.search_steps ~= nil and (not base_depth or base_depth < 2) then
    Cli.die(TOOL, "--search-steps must be a number of 2 or more")
end
local deep_search = base_depth ~= nil and base_depth ~= Pipeline.DEFAULTS.max_steps
if base_depth then ctx.opt.max_steps = base_depth end

-- A condition asking for longer routes than the search reaches widens it, and
-- the report says so: those routes are not in explore's list.
local search_depth = base_depth or Pipeline.DEFAULTS.max_steps
if type(cond.max_steps) == "number" and cond.max_steps > search_depth then
    search_depth = cond.max_steps
end
if type(cond.min_steps) == "number" and cond.min_steps > search_depth then
    search_depth = cond.min_steps
end
local routes, found = Pipeline.search(ctx, { drive_rush = opt.drive_rush == true,
                                             max_steps = search_depth })

-- --- the logs ------------------------------------------------------------------

local logs = Pipeline.load_logs(opt.data, ctx.char_lc, Cli.list_dir)
local records = {}
local other_scheme = 0
for _, log in ipairs(logs) do
    for _, rec in ipairs(log.records) do
        -- A log from another control scheme is about other inputs for the same
        -- action ids. A record that does not say is kept: absence is not a
        -- different scheme.
        if rec.control_scheme == nil or rec.control_scheme == opt.scheme then
            records[#records + 1] = rec
        else
            other_scheme = other_scheme + 1
        end
    end
end
local edges, problems, fold_counts = ConfirmedEdge.from_trials(records)

local wl_main = json.load_file(("%s/%s-%s.json"):format(Pipeline.WL_DIR, ctx.char_lc, opt.scheme))
local route_defs = Pipeline.load_route_defs(opt.data, Cli.list_dir)
local model = SweepReport.build(wl_main or { pairs = {} }, logs, route_defs,
    Pipeline.classic_by_id(ctx.raw))
-- What each action id presses, so an answer recorded under the id the sweep
-- folded a notation group onto is found for the id the route was kept under.
local notation_of = {}
for _, row in ipairs(ctx.cat.rows) do
    notation_of[("%s:%s"):format(row.action_id, row.input_method)] = row.notation
end

-- --- the same runs, judged by the policy the lab database applies ------------------
--
-- Read again from the files rather than from `logs`: tools/lua/labrows.lua
-- wants the line number and the file's base name (which file supersedes which,
-- and which one swept a fixed gap), and ResultCollector's rule about an
-- unterminated last line - so the rows here are the rows tools/db/lab-import.mjs
-- builds, and a status on this page is the status in the database.
local trial_files = LabKnown.load_trials(opt.data, ctx.char_lc, Cli.list_dir)
local lab_lookup = LabKnown.lookup(ctx.opt.character, opt.scheme,
    LabRows.pair_index(ctx.plain_edges, gen and gen.excluded, Pipeline.edge_pair_key),
    notation_of, route_defs)
local evaluations, lab_problems, policy, lab_counts = LabKnown.from_files(trial_files, lab_lookup, {
    keep = function(rec)
        return rec.control_scheme == nil or rec.control_scheme == opt.scheme
    end,
})
for _, p in ipairs(lab_problems or {}) do
    io.stderr:write(TOOL .. ": labeval: " .. tostring(p) .. "\n")
end
local exclusions = LabKnown.exclusions(evaluations)

local known = Planner.known_from(edges, model.combos, notation_of, evaluations)

-- --- the plan ------------------------------------------------------------------

-- What a condition needs that is not written on the route. Only the mechanism
-- today: CandidateGenerator names it on the EDGE and RouteSearch does not copy
-- it onto the step, so first_pair_mechanism would have nothing to read. By the
-- edge the step came through when it names one, and by key otherwise - the same
-- two-step lookup the worklist writer below uses.
local index = Pipeline.edge_index(ctx)
local env = {
    mechanism_of = function(p)
        local e = (p.edge_id and index.by_id[p.edge_id]) or index.by_key[p.key]
        if not e then return nil end
        return CG.mechanism(e)
    end,
}

local plan, perr = Planner.plan(routes, {
    cond = cond, sort = opt.sort, top = top, known = known, env = env,
    demote_rejected = opt.demote_rejected ~= false,
    include_verified = opt.include_verified == true,
})
if not plan then Cli.die(TOOL, perr) end

local name = opt.name and Planner.slug(opt.name) or Planner.default_name(cond, opt.sort, top)

-- --- how a route reads --------------------------------------------------------------

local function modern_chain(route)
    local parts = {}
    for _, s in ipairs(route.steps) do
        if s.kind == RouteSearch.VIA_DRIVE_RUSH then parts[#parts + 1] = "[DRC]"
        elseif s.kind ~= nil then parts[#parts + 1] = "[" .. tostring(s.kind) .. "]"
        else parts[#parts + 1] = tostring(s.notation) end
    end
    return table.concat(parts, " → ")
end

local function classic_chain(route)
    local parts, any = {}, false
    for _, s in ipairs(route.steps) do
        if s.kind ~= nil then parts[#parts + 1] = "DRC"
        else
            if s.classic then any = true end
            parts[#parts + 1] = s.classic and tostring(s.classic) or "?"
        end
    end
    return any and table.concat(parts, " → ") or "-"
end

local function gauge_of(route)
    local s = route.offline_score
    local bits = {}
    if s.od_steps > 0 then bits[#bits + 1] = ("OD %d"):format(s.od_steps) end
    if s.super_steps > 0 then bits[#bits + 1] = ("SA %d"):format(s.super_steps) end
    if (s.drive_rush_cancel_steps or 0) > 0 then
        bits[#bits + 1] = ("DRC %d"):format(s.drive_rush_cancel_steps)
    end
    if s.drive_spend_known then
        bits[#bits + 1] = ("drive %d"):format(s.predicted_drive_spend)
    else
        local floor = route.basis and route.basis.predicted_drive_spend or 0
        bits[#bits + 1] = ("drive >=%d (%d unknown)"):format(floor, s.drive_spend_unknown_steps or 0)
    end
    return table.concat(bits, ", ")
end

-- What the logs already say about a whole route, in one sentence.
local function route_status(a)
    if a.confirmed then return "confirmed combo" end
    local bits = {}
    if a.combo_policy == "observed_success" or a.combo_policy == "mixed" then
        bits[#bits + 1] = "linked once as a combo"
    elseif a.combo_status == "once" or a.combo_status == "confirmed" then
        -- The looser count says it linked; the policy did not count enough of
        -- those runs to call it reproduced. Both are said, because a reader
        -- comparing this to the page has to see which rule each number is.
        bits[#bits + 1] = "the logs list links the policy did not count"
    end
    if a.all_pairs_verified then
        bits[#bits + 1] = "every pair reproduced"
    else
        bits[#bits + 1] = ("%d/%d pairs reproduced"):format(a.pairs_verified, a.pairs_total)
    end
    if #a.linked_once_pairs > 0 then
        bits[#bits + 1] = ("linked once: %s"):format(table.concat(a.linked_once_pairs, ", "))
    end
    if a.has_rejected_pair then
        bits[#bits + 1] = "REJECTED pair: " .. table.concat(a.rejected_pairs, ", ")
    end
    if #a.asked_badly_pairs > 0 then
        bits[#bits + 1] = ("never asked properly: %s"):format(table.concat(a.asked_badly_pairs, ", "))
    end
    return table.concat(bits, "; ")
end

-- --- the worklist ------------------------------------------------------------------

local items, unmatched = {}, {}
for _, p in ipairs(plan.sweep) do
    -- By the edge the route step came through when it names one, and by key
    -- otherwise. A pair with neither is reported, not invented.
    local e = (p.edge_id and index.by_id[p.edge_id]) or index.by_key[p.key]
    if not e then
        unmatched[#unmatched + 1] = p.key
    else
        local item = Pipeline.worklist_item(e)
        item.needed_by_ranks = p.needed_by_ranks
        item.known_status = p.known_status
        -- The keys the answer was recorded under, when it was another action id
        -- with the same buttons: the sweep folds this pair onto the id the
        -- calibration measured, so its trials carry that id, not this one.
        item.known_as = p.known_as
        items[#items + 1] = item
        p.item = item
    end
end

-- The chosen routes, as numbers another tool can read.
--
-- WHY IN THE WORKLIST. The plan's report is prose for a person; the route files
-- are for the game and carry no prediction at all. Nothing carried "the plan
-- picked this route, and here is what it predicts" in a form a page could read,
-- so tools/lua/report.lua re-derived it, badly, by matching notation strings.
-- It goes in the worklist's `plan` block because the worklist is the document
-- that already says what this plan is, and because adding a field beside
-- `pairs` changes nothing for a reader of ce.worklist.v1's pairs.
--
-- Every figure here is a PREDICTION from the frame data, the same one the
-- report prints. `route_file` is named whether or not --routes wrote it - it is
-- the name plan.lua would give it - and `route_file_written` says which.
local plan_routes = {}
for i, a in ipairs(plan.routes) do
    local r = a.route
    local s = r.offline_score or {}
    local steps = {}
    for _, st in ipairs(r.steps or {}) do
        if st.kind ~= nil then
            steps[#steps + 1] = { drc = true }
        else
            steps[#steps + 1] = { action_id = st.action_id, notation = st.notation,
                                  classic = st.classic, input_method = st.input_method }
        end
    end
    local pair_keys = {}
    for pi, p in ipairs(Planner.route_pairs(r)) do
        pair_keys[pi] = { key = p.key, status = a.pair_statuses and a.pair_statuses[pi] or nil,
                          mechanism = env.mechanism_of(p) }
    end
    plan_routes[i] = {
        rank = i,
        sort_rank = a.sort_rank,
        id = r.id,
        notation = modern_chain(r),
        classic = classic_chain(r),
        steps = steps,
        pairs = pair_keys,
        predicted_damage_scaled = s.predicted_damage_scaled,
        predicted_damage = s.predicted_damage,
        predicted_damage_complete = s.predicted_damage_complete,
        input_count = s.input_count,
        execution_cost = s.execution_cost,
        route_length = s.route_length,
        hardest_motion = s.hardest_motion,
        gauge = gauge_of(r),
        od_steps = s.od_steps, super_steps = s.super_steps,
        drive_rush_cancel_steps = s.drive_rush_cancel_steps,
        predicted_drive_spend = s.predicted_drive_spend,
        drive_spend_known = s.drive_spend_known,
        theoretical_confidence = s.theoretical_confidence,
        pairs_total = a.pairs_total, pairs_verified = a.pairs_verified,
        status = route_status(a),
        route_file = RouteFile.file_name(ctx.char_lc, opt.scheme, name, i),
        route_file_written = (i <= want_routes) or nil,
    }
end

local conditions_doc = {}
for k, v in pairs(cond) do conditions_doc[k] = v end
-- No conditions is an empty OBJECT, not an empty list: `conditions: []` would
-- read as a list of conditions that happens to be empty.
if next(conditions_doc) == nil then conditions_doc = json.EMPTY_OBJECT end
local generated_at = ctx.provenance.generated_at
local wl_doc, werr = Pipeline.worklist_doc(ctx, items, {
    plan = {
        name = name,
        conditions = conditions_doc,
        sort = opt.sort,
        sort_field = plan.rank.field,
        sort_fallback = plan.rank.fallback or nil,
        top = top,
        drive_rush = opt.drive_rush == true,
        include_verified = opt.include_verified == true,
        demote_rejected = opt.demote_rejected ~= false,
        generated_at = generated_at,
        -- Said in the document, not only in the report: this order is route
        -- rank, and a reader expecting explore's confidence order would
        -- misread which pairs were meant to go first.
        order = "route rank: every pair of the best route first, then the next route's new pairs",
        search = {
            max_steps = search_depth,
            beam = ctx.opt.beam,
            -- How many routes the SEARCH found, before any condition. `available`
            -- below is how many survived the conditions, and the two are easy to
            -- print in place of each other.
            routes_found = plan.filter.input,
            complete = found.stats.complete,
            beam_dropped = found.stats.beam_dropped_total,
            truncated_routes = found.stats.truncated_routes,
            deep = deep_search or nil,
        },
        available = plan.available,
        routes = plan_routes,
        routes_are_predictions = "every figure on a route here is predicted from the frame "
            .. "data. Nothing in this file has been run on the game.",
    },
})
if not wl_doc then Cli.die(TOOL, werr) end

Cli.mkdir(Pipeline.WL_DIR)
local wl_path = ("%s/%s-%s-plan-%s.json"):format(Pipeline.WL_DIR, ctx.char_lc, opt.scheme, name)
local wl_bytes, wl_err = json.save_file(wl_path, wl_doc, { indent = "  " })
if not wl_bytes then Cli.die(TOOL, ("could not write %s: %s"):format(wl_path, tostring(wl_err))) end

-- --- the route files --------------------------------------------------------------
--
-- The plan's best routes, written where runtime/RouteRun.lua reads them. This
-- is the other half of #36/#37: the pairs that linked are known, the routes
-- built from them are what "a verified combo with measured damage" needs, and
-- until now nothing wrote the file the game would run.
--
-- Every gap gets a list, and the file says where each list came from. See
-- tools/lua/routefile.lua: measured beats predicted beats the default range,
-- and no gap ever gets one invented number.

local ROUTE_DIR = opt.data .. "/route"
local known_by_key = {}
for _, p in ipairs(plan.pairs) do known_by_key[p.key] = p end

-- The two numbers runtime/Sweep hands Timing, from the same place the panel
-- takes them: a fresh Provenance register. The input buffer is what a link
-- window needs and nothing else here carries it, so without this every link
-- pair falls back to the default range with "missing: input_buffer_ticks".
local reg = Provenance.new()
local buffer_ticks, buffer_status = Provenance.provisional(reg, "input_buffer_ticks")
local SWEEP_OPTS = { hold_ticks = 3, buffer_ticks = buffer_ticks }

local routes_written, routes_refused = {}, {}
if want_routes > 0 then
    Cli.mkdir(ROUTE_DIR)
    for rank = 1, math.min(want_routes, #plan.routes) do
        local a = plan.routes[rank]
        local r = a.route
        local id = RouteFile.file_name(ctx.char_lc, opt.scheme, name, rank)
        local gaps, refused = {}, nil
        for i, p in ipairs(Planner.route_pairs(r)) do
            local entry = known_by_key[p.key]
            local e = (index.by_id[p.edge_id] or index.by_key[p.key])
            local g = RouteFile.delays_for({
                entry = entry and entry.known or nil,
                item = e and Pipeline.worklist_item(e) or nil,
                plan_for = Sweep.plan_for,
                sweep_opts = SWEEP_OPTS,
                policy_key = policy and policy.key,
                no_window_reason = e and "the frame data gives no window for this pair"
                    or ("no candidate edge carries `%s`, so there is nothing to predict from")
                        :format(p.key),
            })
            g.pair = p.key
            gaps[i] = g
        end
        local doc, info = RouteFile.build(r, {
            id = id, character = ctx.opt.character, control_scheme = opt.scheme,
            gaps = gaps,
            plan = { name = name, rank = rank, sort = opt.sort,
                     generated_at = generated_at, tool = "tools/lua/plan.lua --routes",
                     conditions = conditions_doc },
            status = (function()
                local bits = { ("%d/%d pairs reproduced"):format(a.pairs_verified, a.pairs_total) }
                if a.combo_policy then
                    bits[#bits + 1] = ("by its moves, pressed any way, the policy calls this "
                        .. "combo %s"):format(a.combo_policy)
                end
                if a.has_rejected_pair then
                    bits[#bits + 1] = "a pair of it was conclusively rejected: "
                        .. table.concat(a.rejected_pairs, ", ")
                end
                if #a.asked_badly_pairs > 0 then
                    bits[#bits + 1] = "a pair of it has never been asked properly: "
                        .. table.concat(a.asked_badly_pairs, ", ")
                end
                return table.concat(bits, "; ")
            end)(),
        })
        if not doc then
            refused = info
            routes_refused[#routes_refused + 1] = { rank = rank, reason = tostring(refused) }
        else
            local path = ("%s/%s.json"):format(ROUTE_DIR, id)
            local bytes, werr2 = json.save_file(path, doc, { indent = "  " })
            if not bytes then
                Cli.die(TOOL, ("could not write %s: %s"):format(path, tostring(werr2)))
            end
            -- Proof the game will take it, made from the document just written
            -- rather than from the table it came from: a file that loads and is
            -- then refused looks like something to run.
            local built, why = Route.build(json.load_file(path))
            if not built then
                Cli.die(TOOL, ("wrote %s and core/Route.build refuses it: %s")
                    :format(path, tostring(why)))
            end
            routes_written[#routes_written + 1] = {
                rank = rank, id = id, path = path, bytes = bytes, info = info,
                gaps = gaps, ann = a,
            }
        end
    end
end

-- --- the report --------------------------------------------------------------------

local rep = Cli.report()
local function say(fmt, ...) return rep:say(fmt, ...) end

local function cell(s) return (tostring(s):gsub("|", "\\|")) end

local scheme_label = opt.scheme
say("# Route plan - %s / %s - %s", ctx.opt.character, scheme_label, name)
say("")
say("Generated %s by `lua tools/lua/plan.lua`. Do not edit by hand; rerun it.", generated_at)
say("")
say("EVERY ROUTE HERE IS A THEORETICAL CANDIDATE. The ranking is a prediction from")
say("the frame data. The worklist below is the smallest set of pairs that lets the")
say("game say whether these routes connect.")
say("")

say("## Conditions")
say("")
local cond_keys = {}
for _, k in ipairs(Planner.FILTER_ORDER) do
    if cond[k] ~= nil and cond[k] ~= false then cond_keys[#cond_keys + 1] = k end
end
if #cond_keys == 0 then
    say("- none: every route the search found")
else
    for _, k in ipairs(cond_keys) do say("- `%s` = `%s`", k, tostring(cond[k])) end
end
say("- sort: `%s`, top %d", opt.sort, top)
local depth_note = ""
if deep_search and search_depth > base_depth then
    depth_note = (" - %d for --search-steps, widened again for the step condition")
        :format(base_depth)
elseif deep_search then
    depth_note = (" - --search-steps, deeper than explore.lua's %d")
        :format(Pipeline.DEFAULTS.max_steps)
elseif search_depth ~= Pipeline.DEFAULTS.max_steps then
    depth_note = (" - widened from %d for the step condition"):format(Pipeline.DEFAULTS.max_steps)
end
say("- search: explore.lua's settings (%s -> %s, %s -> %s, max %d moves%s, beam %d, collapse %s)",
    ctx.opt.from_categories, ctx.opt.to_categories, ctx.opt.from_methods, ctx.opt.to_methods,
    search_depth, depth_note, ctx.opt.beam, tostring(ctx.opt.collapse))
say("- search complete: %s%s", tostring(found.stats.complete),
    found.stats.complete and " - every route the settings can reach is in the list below"
        or (" - the beam dropped %d partial route(s) and %d route(s) were not emitted, so "
            .. "the list below is a sample"):format(found.stats.beam_dropped_total or 0,
                                                    found.stats.truncated_routes or 0))
say("- Drive Rush Cancel edges in the search: %s", opt.drive_rush and "yes" or
    "no (pass --drive-rush to route through them)")
say("- demote routes through a rejected pair: %s", opt.demote_rejected ~= false and "yes" or "no")
say("")
if cond.starter_button then
    say("`starter_button` keeps a route whose first move has that button with ANY direction")
    say("(中 keeps 中, 2 + 中, 3 + 中, 6 + 中). `--starter-neutral` narrows it to no direction.")
    say("")
end
if cond.no_gauge then
    say("`no_gauge` removes a route with an OD move, a super, a Drive Rush Cancel, or any")
    say("KNOWN Drive or Super spend. A route where some move has no Drive figure is kept and")
    say("flagged: nothing in the source says it spends, and a missing value never excludes.")
    say("")
end

say("## Damage figure")
say("")
if plan.rank.fallback then
    say("**Scaled damage is not available in this build of Scoring.** %s.", plan.rank.fallback_reason)
    say("The `dmg scaled` column is empty for that reason. Rerun this plan once")
    say("`offline_score.%s` exists and the order will follow it.", Planner.SCALED_FIELD)
elseif opt.sort == "scaled_damage" then
    say("Ordered on `offline_score.%s`, the combo-scaled prediction.", Planner.SCALED_FIELD)
else
    say("Ordered on `offline_score.%s`.", tostring(plan.rank.field))
end
if (plan.rank.missing or 0) > 0 then
    say("")
    say("%d route(s) carry no value on that field and are ranked after the rest, not removed.",
        plan.rank.missing)
end
say("")
say("Unscaled damage is a frame-table sum: an upper bound for ordering when complete,")
say("never a damage figure.")
say("")

say("## What each condition removed")
say("")
say("- routes found by the search: %d (search complete: %s)", plan.filter.input,
    tostring(found.stats.complete))
if not found.stats.complete then
    say("  - the beam dropped %d partial routes and %d routes were not emitted, so a route",
        found.stats.beam_dropped_total or 0, found.stats.truncated_routes or 0)
    say("    satisfying these conditions may be missing")
end
say("")
if #plan.filter.steps > 0 then
    say("| condition | value | before | removed | after | kept on a gap |")
    say("|---|---|---:|---:|---:|---:|")
    for _, st in ipairs(plan.filter.steps) do
        say("| %s | %s | %d | %d | %d | %d |", st.name, cell(st.value), st.before, st.removed,
            st.after, st.flagged)
    end
    say("")
end
say("- routes satisfying every condition: %d", plan.filter.kept)
say("- of those, through a pair the policy CONCLUSIVELY rejected: %d (ranked after the "
    .. "clean ones%s)", plan.through_rejected,
    opt.demote_rejected ~= false and "" or " - off for this plan")
say("- in this plan (top %d): %d", top, #plan.routes)
say("")
say("Demotion counts conclusive failures only. Under policy `%s` a negative is one when "
    .. "the run pressed a playable input at the right timing; %d of %d runs were left out "
    .. "for asking something else, %d of them negatives. %d pair(s) changed status "
    .. "because of it.", tostring(policy and policy.key), exclusions.excluded,
    exclusions.excluded + exclusions.counted, exclusions.negatives_excluded,
    known.reclassified.total)
say("")
if #plan.demoted_out > 0 then
    say("### Moved below the top %d by a rejected pair: %d", top, #plan.demoted_out)
    say("")
    say("The sort alone would have put these in the plan. They are not deleted - they")
    say("rank after every clean route, and `--no-demote-rejected` puts them back. Some")
    say("rejections in the logs come from experiments later found broken (#46, #49).")
    say("")
    for _, a in ipairs(plan.demoted_out) do
        say("- sort #%d %s - rejected: %s", a.rank, cell(modern_chain(a.route)),
            table.concat(a.rejected_pairs, ", "))
    end
    say("")
end

say("## Routes")
say("")
say("`#` is the plan order; `sort` is where the route stood before routes through a")
say("rejected pair were moved behind the clean ones.")
say("")
say("| # | sort | route (Modern) | classic | dmg scaled | dmg unscaled | gauge | cost | conf | status |")
say("|---:|---:|---|---|---:|---:|---|---:|---|---|")
for _, a in ipairs(plan.routes) do
    local r, s = a.route, a.route.offline_score
    local scaled = s[Planner.SCALED_FIELD]
    local unscaled = s.predicted_damage
    say("| %d | %d | %s | %s | %s | %s%s | %s | %.1f | %s | %s |",
        a.plan_rank, a.sort_rank, cell(modern_chain(r)), cell(classic_chain(r)),
        type(scaled) == "number" and tostring(math.floor(scaled + 0.5)) or "-",
        unscaled and tostring(unscaled) or "-",
        s.predicted_damage_complete and "" or " (incomplete)",
        gauge_of(r), s.execution_cost, tostring(s.theoretical_confidence), cell(route_status(a)))
end
say("")

local flagged_ids = {}
for _, a in ipairs(plan.routes) do
    if plan.filter.flags[tostring(a.id)] then flagged_ids[#flagged_ids + 1] = a end
end
if #flagged_ids > 0 then
    say("### Kept on a gap")
    say("")
    say("These satisfy the conditions on what is known; a condition could not be fully")
    say("judged because the source has no figure.")
    say("")
    for _, a in ipairs(flagged_ids) do
        for _, f in ipairs(plan.filter.flags[tostring(a.id)]) do
            say("- #%d `%s`: %s - %s", a.plan_rank, a.id, f.filter, tostring(f.reason))
        end
    end
    say("")
end

say("## Pairs to sweep: %d", #items)
say("")
say("In the order the worklist holds them. `needed by` lists the plan ranks of the")
say("routes containing the pair. The full worklist has %d pairs.",
    wl_main and #(wl_main.pairs or {}) or 0)
say("")
local unpressable = 0
if #plan.routes == 0 then
    say("None: no route satisfies these conditions.")
elseif #plan.sweep == 0 then
    say("None. Every pair these routes need is already answered.")
else
    say("`press` is what the sweep's compiler can play (sweepreport.press_kind): `repeat`")
    say("is a direction pressed twice in a row (22), `followup` a move that only exists")
    say("after a specific previous one. The sweep sets both aside rather than pressing")
    say("them (#49), so a plan that needs one needs a route run or a compiler change.")
    say("")
    say("| # | pair | key | needed by | logs say | press | confidence | margin |")
    say("|---:|---|---|---|---|---|---|---:|")
    for i, p in ipairs(plan.sweep) do
        local item = p.item
        local margin = item and (item.margin_frames or item.drc_margin_frames)
        local press_a = SweepReport.press_kind(p.a.notation)
        local press_b = SweepReport.press_kind(p.b.notation)
        local press = press_a ~= SweepReport.PRESS.OK and press_a or press_b
        if press ~= SweepReport.PRESS.OK then unpressable = unpressable + 1 end
        say("| %d | %s | `%s` | %s | %s | %s | %s | %s |", i,
            cell(("%s → %s%s"):format(tostring(p.a.notation), p.drc and "DRC → " or "",
                tostring(p.b.notation))),
            p.key, table.concat(p.needed_by_ranks, ", "),
            p.known_status .. ((p.known and p.known.mixed) and " (mixed)" or "")
                .. (p.known_as and (" as `" .. table.concat(p.known_as, "`, `") .. "`") or ""),
            press, item and tostring(item.confidence) or "?",
            margin ~= nil and tostring(margin) or "-")
    end
    if unpressable > 0 then
        say("")
        say("**%d of these the sweep cannot press as written.**", unpressable)
    end
end
say("")
if #unmatched > 0 then
    say("**%d pair(s) had no candidate edge to write** and are missing from the worklist:", #unmatched)
    for _, k in ipairs(unmatched) do say("- `%s`", k) end
    say("")
end

local function pair_detail(p)
    local parts = {}
    for _, key in ipairs(p.known_as or { p.key }) do
        local entry = known.pairs[key]
        for _, e in ipairs(entry and entry.evaluations or {}) do
            local bits = {}
            for reason, n in pairs(e.excluded_by_reason or {}) do
                bits[#bits + 1] = ("%s %d"):format(reason, n)
            end
            table.sort(bits)
            parts[#parts + 1] = ("%s%s (%d linked / %d counted no / %d left out%s)"):format(
                p.known_as and ("as " .. key .. " ") or "", tostring(e.result),
                e.successes or 0, e.failures or 0, e.excluded or 0,
                #bits > 0 and (": " .. table.concat(bits, ", ")) or "")
        end
    end
    if #parts == 0 then return "no evaluation carries this pair" end
    return table.concat(parts, "; ")
end

local by_status = {}
for _, p in ipairs(plan.sweep) do
    local st = p.known_status
    by_status[st] = by_status[st] or {}
    table.insert(by_status[st], p)
end

local rejected_kept = by_status[Planner.KNOWN.REJECTED] or {}
if #rejected_kept > 0 then
    say("### Conclusively rejected pairs kept in the sweep: %d", #rejected_kept)
    say("")
    say("Policy `%s` counted these negatives: the input was one the compiler can press,",
        tostring(policy and policy.key))
    say("at a timing that could have answered, and nothing linked. A \"no\" like that is")
    say("still not trusted enough to delete a route - it is an answer about the delays")
    say("that were tried - so the pair is asked again, after the clean routes' pairs when")
    say("demotion is on.")
    say("")
    for _, p in ipairs(rejected_kept) do say("- `%s`: %s", p.key, pair_detail(p)) end
    say("")
end

local asked_badly = by_status[Planner.KNOWN.ASKED_BADLY] or {}
if #asked_badly > 0 then
    say("### Pairs whose every negative was thrown out: %d", #asked_badly)
    say("")
    say("Trials were spent on these and none of them asked whether the pair links: the")
    say("fixed gap of 4 inside A's animation (#46), a cancel-only pair pressed at the link")
    say("gap after A had recovered, B's button a motion's worth of ticks late, or an input")
    say("today's compiler would not press (#49). They read as `pending` to the plan and")
    say("they do NOT demote a route - nobody has asked yet.")
    say("")
    for _, p in ipairs(asked_badly) do say("- `%s`: %s", p.key, pair_detail(p)) end
    say("")
end

local linked_once = by_status[Planner.KNOWN.LINKED_ONCE] or {}
if #linked_once > 0 then
    say("### Pairs that linked but were never reproduced: %d", #linked_once)
    say("")
    say("The game said yes, and not twice at one delay - which is ConfirmedEdge's rule for")
    say("`stable` and the database's for a confirmed pair. They stay in the sweep: one more")
    say("link at the gap that already worked is the cheapest question in the plan.")
    say("")
    for _, p in ipairs(linked_once) do say("- `%s`: %s", p.key, pair_detail(p)) end
    say("")
end

say("## Already known: %d", #plan.skipped)
say("")
if #plan.skipped == 0 then
    say("Nothing these routes need has been answered yet.")
else
    say("Left out of the worklist%s.", opt.include_verified and "" or
        " (pass --include-verified to keep verified pairs)")
    say("")
    for _, p in ipairs(plan.skipped) do
        local why = p.skip == "verified" and "verified by the game"
            or "every route needing it is already a confirmed combo"
        say("- `%s` (%s → %s): %s%s, needed by %s", p.key, tostring(p.a.notation),
            tostring(p.b.notation), why,
            p.known_as and (" as `" .. table.concat(p.known_as, "`, `") .. "`") or "",
            table.concat(p.needed_by_ranks, ", "))
    end
end
say("")

say("## Where the known statuses come from")
say("")
say("- trial logs read: %d (%d records for %s)", #logs, #records, opt.scheme)
if other_scheme > 0 then say("  - %d records from another control scheme left out", other_scheme) end
say("- pairs answered: %d across %d cohort(s) - raw ConfirmedEdge: verified %d, rejected %d, "
    .. "pending %d", fold_counts.edges, fold_counts.cohorts or 0, fold_counts.verified,
    fold_counts.rejected, fold_counts.pending)
say("- route runs (combos, not pairs): %d rows", fold_counts.route_trials or 0)
local n_confirmed = 0
for _, c in ipairs(model.combos) do if c.status == SweepReport.COMBO.CONFIRMED then n_confirmed = n_confirmed + 1 end end
say("- combos the looser page rule calls confirmed: %d (2+ links at any gap, across input "
    .. "methods, cohorts and gaps, superseded rows included)", n_confirmed)
say("")

say("### Policy `%s`", tostring(policy and policy.key))
say("")
say("%s", tostring(policy and policy.description))
say("")
say("- rows built from the trial files: %d (%d lines, %d committed twice, %d refused)",
    lab_counts.rows, lab_counts.lines, lab_counts.duplicates, lab_counts.problems)
say("- runs counted: %d; left out: %d (of which negatives: %d)",
    exclusions.counted, exclusions.excluded, exclusions.negatives_excluded)
local reasons = {}
for reason, n in pairs(exclusions.by_reason) do reasons[#reasons + 1] = { reason, n } end
table.sort(reasons, function(x, y) return x[1] < y[1] end)
for _, r in ipairs(reasons) do say("  - `%s`: %d", r[1], r[2]) end
say("- evaluations (one per subject per cohort): %d", #evaluations)
local policy_status = {}
for _, k in pairs(known.pairs) do
    policy_status[k.status] = (policy_status[k.status] or 0) + 1
end
local statuses = {}
for st, n in pairs(policy_status) do statuses[#statuses + 1] = ("%s %d"):format(st, n) end
table.sort(statuses)
say("- pairs by status: %s", table.concat(statuses, ", "))
local moved = {}
for m, n in pairs(known.reclassified.moves) do moved[#moved + 1] = ("`%s` %d"):format(m, n) end
table.sort(moved)
say("- reclassified by the policy: %d of %d (%s)", known.reclassified.total,
    known.reclassified.pairs, #moved > 0 and table.concat(moved, ", ") or "none")
say("")
say("A pair measured in several cohorts takes the strongest result: `verified` when some")
say("cohort REPRODUCED it (ConfirmedEdge stable on the counted runs), else `linked_once`")
say("when some cohort linked it, else `rejected` when a cohort answered no on runs the")
say("policy counted, else `asked_badly` when negatives exist and every one of them was")
say("left out, else `pending`. `(mixed)` marks a pair that both linked and conclusively")
say("failed. Only `rejected` demotes a route.")
say("")
say("`as <key>` means the answer was recorded under another action id with the same")
say("buttons. The catalog lists Modern 弱 as 601, 602 and 611; the search keeps one of")
say("them, and the sweep folds every pair onto the id the calibration measured (611)")
say("before pressing it, so that is the id its trials carry.")
say("")

if want_routes > 0 then
    say("## Route files for the next session: %d", #routes_written)
    say("")
    say("`--routes %d` wrote the plan's best routes where the panel's ROUTE section reads",
        want_routes)
    say("them. A route run presses the whole combo and records every gap combination, which")
    say("is what a verified combo with measured damage needs (#36, #37) and what a pair")
    say("sweep cannot give.")
    say("")
    if #routes_written == 0 then
        say("None were written.")
    else
        say("| # | route | file | grid | gap delays (where each came from) |")
        say("|---:|---|---|---:|---|")
        for _, w in ipairs(routes_written) do
            local bits = {}
            for i, g in ipairs(w.gaps) do
                local names = {}
                for j, v in ipairs(g.delays) do names[j] = tostring(v) end
                bits[i] = ("gap %d %s (%s)"):format(i, table.concat(names, "/"), g.source)
            end
            say("| %d | %s | `%s.json` | %d | %s |", w.rank, cell(modern_chain(w.ann.route)),
                w.id, w.info.combinations, cell(table.concat(bits, "; ")))
        end
    end
    say("")
    if #routes_refused > 0 then
        say("%d route(s) could not be written as a file:", #routes_refused)
        for _, r in ipairs(routes_refused) do say("- plan #%d: %s", r.rank, r.reason) end
        say("")
    end
    say("`measured` is the gaps the policy's counted runs linked that pair at; `predicted`")
    say("is runtime/Sweep.plan_for's own grid from the frame data, a link gap widened to the")
    say("window the input buffer covers (`input_buffer_ticks` = %s, %s); `default` is",
        tostring(buffer_ticks), tostring(buffer_status))
    say("core/Route.DEFAULT_DELAYS, which measures nothing and says so. No gap is ever")
    say("given a single invented number.")
    say("")
end

say("## Running it")
say("")
say("Copy the worklist to the game machine (`scripts/install-dev.ps1` syncs")
say("reframework/data), then pick `plan: %s` in the SWEEP panel's worklist list", name)
say("(REFRESH if the panel was already open) and START SWEEP. It writes to the same")
say("trial log as the full sweep, so pairs the full sweep already answered under the")
say("same calibration and conditions are skipped, and the other way round.")
if opt.drive_rush then
    say("Pairs through a Drive Rush Cancel are set aside by the sweep, not pressed: how a")
    say("rush is input on this build has not been measured.")
end
say("")

say("## Written")
say("")
local md_dir = "docs/ComboExplorer/plans"
local md_path = ("%s/%s-%s-%s.md"):format(md_dir, ctx.char_lc, opt.scheme, name)
say("- %s  (%d pairs, %d bytes)", wl_path, #items, wl_bytes)
for _, w in ipairs(routes_written) do
    say("- %s  (%d step(s), %d gap combination(s), %d bytes)", w.path, w.info.steps,
        w.info.combinations, w.bytes)
end
say("- %s", md_path)

Cli.mkdir(md_dir)
local wrote, rerr = rep:write(md_path)
if not wrote then Cli.die(TOOL, ("could not write %s: %s"):format(md_path, tostring(rerr))) end
