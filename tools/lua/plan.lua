-- =========================================================
-- tools/lua/plan.lua - state the conditions first, then sweep only the pairs
-- the routes that satisfy them need.
--
--   lua tools/lua/plan.lua --character Zangief [--scheme modern]
--       [--starter-button 中 | --starter-notation "2 + 中" | --starter-id 604]
--       [--starter-neutral] [--input-method manual|simple|assist]
--       [--no-gauge] [--no-super] [--no-drive-rush] [--max-drive-bars N]
--       [--min-steps N] [--max-steps N] [--min-confidence low|medium|high]
--       [--sort scaled_damage|damage|simple|confidence] [--top 20]
--       [--name <plan name>] [--drive-rush] [--include-verified]
--       [--no-demote-rejected]
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
--
-- NOTHING THIS PRODUCES IS A COMBO, for explore.lua's reason. A route in a plan
-- is a reason to spend trials on the game, ranked by a prediction.

local Cli = dofile("tools/lua/cli.lua")

local json        = dofile("tools/lua/json.lua")
local Pipeline    = dofile("tools/lua/pipeline.lua")
local Planner     = dofile("tools/lua/planner.lua")
local SweepReport = dofile("tools/lua/sweepreport.lua")
local ConfirmedEdge = require("func/ComboExplorer/core/ConfirmedEdge")
local RouteSearch = require("func/ComboExplorer/core/RouteSearch")

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
for _, k in ipairs({ "starter_button", "starter_notation", "starter_id" }) do
    if cond[k] ~= nil then exclusive = exclusive + 1 end
end
if exclusive > 1 then
    Cli.die(TOOL, "give one of --starter-button, --starter-notation and --starter-id, not several")
end
if not Planner.SORTS[opt.sort] then
    Cli.die(TOOL, ("--sort must be scaled_damage, damage, simple or confidence, not %q")
        :format(tostring(opt.sort)))
end
local top = tonumber(opt.top)
if not top or top < 1 then Cli.die(TOOL, "--top must be a positive number") end

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

-- A condition asking for longer routes than explore searches widens the search
-- to reach them, and the report says so: those routes are not in explore's list.
local search_depth = Pipeline.DEFAULTS.max_steps
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
local model = SweepReport.build(wl_main or { pairs = {} }, logs,
    Pipeline.load_route_defs(opt.data, Cli.list_dir), Pipeline.classic_by_id(ctx.raw))
-- What each action id presses, so an answer recorded under the id the sweep
-- folded a notation group onto is found for the id the route was kept under.
local notation_of = {}
for _, row in ipairs(ctx.cat.rows) do
    notation_of[("%s:%s"):format(row.action_id, row.input_method)] = row.notation
end
local known = Planner.known_from(edges, model.combos, notation_of)

-- --- the plan ------------------------------------------------------------------

local plan, perr = Planner.plan(routes, {
    cond = cond, sort = opt.sort, top = top, known = known,
    demote_rejected = opt.demote_rejected ~= false,
    include_verified = opt.include_verified == true,
})
if not plan then Cli.die(TOOL, perr) end

local name = opt.name and Planner.slug(opt.name) or Planner.default_name(cond, opt.sort, top)

-- --- the worklist ------------------------------------------------------------------

local index = Pipeline.edge_index(ctx)
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
    },
})
if not wl_doc then Cli.die(TOOL, werr) end

Cli.mkdir(Pipeline.WL_DIR)
local wl_path = ("%s/%s-%s-plan-%s.json"):format(Pipeline.WL_DIR, ctx.char_lc, opt.scheme, name)
local wl_bytes, wl_err = json.save_file(wl_path, wl_doc, { indent = "  " })
if not wl_bytes then Cli.die(TOOL, ("could not write %s: %s"):format(wl_path, tostring(wl_err))) end

-- --- the report --------------------------------------------------------------------

local rep = Cli.report()
local function say(fmt, ...) return rep:say(fmt, ...) end

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

local function cell(s) return (tostring(s):gsub("|", "\\|")) end

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

local function route_status(a)
    if a.confirmed then return "confirmed combo" end
    local bits = {}
    if a.combo_status == "once" then bits[#bits + 1] = "linked once as a combo" end
    if a.all_pairs_verified then
        bits[#bits + 1] = "every pair verified"
    else
        bits[#bits + 1] = ("%d/%d pairs verified"):format(a.pairs_verified, a.pairs_total)
    end
    if a.has_rejected_pair then
        bits[#bits + 1] = "REJECTED pair: " .. table.concat(a.rejected_pairs, ", ")
    end
    return table.concat(bits, "; ")
end

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
say("- search: explore.lua's settings (%s -> %s, %s -> %s, max %d moves%s, beam %d, collapse %s)",
    ctx.opt.from_categories, ctx.opt.to_categories, ctx.opt.from_methods, ctx.opt.to_methods,
    search_depth, search_depth ~= Pipeline.DEFAULTS.max_steps
        and (" - widened from %d for the step condition"):format(Pipeline.DEFAULTS.max_steps) or "",
    ctx.opt.beam, tostring(ctx.opt.collapse))
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
say("- of those, through a pair the logs rejected: %d (ranked after the clean ones%s)",
    plan.through_rejected, opt.demote_rejected ~= false and "" or " - off for this plan")
say("- in this plan (top %d): %d", top, #plan.routes)
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

local rejected_kept = {}
for _, p in ipairs(plan.sweep) do
    if p.known_status == Planner.KNOWN.REJECTED then rejected_kept[#rejected_kept + 1] = p end
end
if #rejected_kept > 0 then
    say("### Rejected pairs kept in the sweep: %d", #rejected_kept)
    say("")
    say("A \"no\" in the committed logs is not trusted enough to delete a route. Some of")
    say("those experiments were later found broken: the fixed delay of 4 that pressed B")
    say("inside A's cancel window (#46), and follow-ups pressed after a move they cannot")
    say("come out of (#49). These pairs are asked again, after the clean routes' pairs")
    say("when demotion is on.")
    say("")
    for _, p in ipairs(rejected_kept) do
        local parts = {}
        for _, key in ipairs(p.known_as or { p.key }) do
            local entry = known.pairs[key]
            for _, c in ipairs(entry and entry.cohorts or {}) do
                parts[#parts + 1] = ("%s%s (%s: %d/%d linked)"):format(
                    p.known_as and ("as " .. key .. " ") or "", tostring(c.status),
                    tostring(c.calibration_id), c.successes or 0,
                    (c.successes or 0) + (c.negatives or 0))
            end
        end
        say("- `%s`: %s", p.key, table.concat(parts, "; "))
    end
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
say("- pairs answered: %d across %d cohort(s) - verified %d, rejected %d, pending %d",
    fold_counts.edges, fold_counts.cohorts or 0, fold_counts.verified, fold_counts.rejected,
    fold_counts.pending)
say("- route runs (combos, not pairs): %d rows", fold_counts.route_trials or 0)
local n_confirmed = 0
for _, c in ipairs(model.combos) do if c.status == SweepReport.COMBO.CONFIRMED then n_confirmed = n_confirmed + 1 end end
say("- combos confirmed in the logs: %d", n_confirmed)
say("")
say("A pair measured in several cohorts is `verified` if any cohort linked it, else")
say("`rejected` if any answered no, else `pending`. `(mixed)` marks a pair one cohort")
say("linked and another rejected.")
say("")
say("`as <key>` means the answer was recorded under another action id with the same")
say("buttons. The catalog lists Modern 弱 as 601, 602 and 611; the search keeps one of")
say("them, and the sweep folds every pair onto the id the calibration measured (611)")
say("before pressing it, so that is the id its trials carry.")
say("")

say("## Running it")
say("")
say("The in-game SWEEP panel reads `worklist/<char>-<scheme>.json` by that exact name.")
say("To sweep this plan, put the plan's worklist in its place on the game machine")
say("(keep the full one aside), or teach the panel to pick a file.")
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
say("- %s", md_path)

Cli.mkdir(md_dir)
local wrote, rerr = rep:write(md_path)
if not wrote then Cli.die(TOOL, ("could not write %s: %s"):format(md_path, tostring(rerr))) end
