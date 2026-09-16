-- =========================================================
-- tools/lua/practice.lua - which character is predicted to be the easiest to
-- learn combos on, from the offline data this repo already produces.
--
--   lua tools/lua/practice.lua                 (full run: ~1 minute)
--   lua tools/lua/practice.lua --from-cache    (re-render from practice.json)
--
-- Writes docs/ComboExplorer/practice.md, practice.html and practice.json.
-- Needs Lua 5.4, the catalogs, data/frame-data and the committed worklists.
-- No game, no network. Run from the repo root, like every other tool.
-- =========================================================
--
-- WHAT THIS ANSWERS, AND HOW HONESTLY
--
-- The question is "which character is easiest to learn combos on". The honest
-- answer this data can give is a PREDICTION from the frame table and the shape
-- of the inputs. It is not measured difficulty. Nobody has measured a single
-- link's frame window on this build, and only Zangief has been to the lab at
-- all - 6 confirmed combos out of 1000 trials. Every other character's row is
-- arithmetic over numbers that have never been checked against the game.
--
-- So the word "predicted" is not decoration and is never dropped, here or in
-- what this writes.
--
-- WHY IT RUNS THE PIPELINE AGAIN
--
-- docs/ComboExplorer/characters.json already has per-character totals and this
-- reuses them: the frame-data join, the worklist confidence split, the pair
-- counts. What it does not have is anything PER ROUTE - execution_cost,
-- predicted_damage_scaled, hardest_motion - and four of the five components
-- are about the routes. So the pipeline runs again, with explore.lua's
-- settings by way of tools/lua/pipeline.lua, and the routes are reduced to a
-- dozen numbers each (practicescore.route_summary) rather than held whole.
--
-- The whole roster takes about a minute. Drive Rush Cancel edges are left out,
-- so these are explore's routes and the route counts line up with the ones
-- already on the index page.
--
-- WHY --from-cache EXISTS
--
-- all.lua --index-only rebuilds the pages from the last run's numbers without
-- running anything, and this has to fit that. practice.json holds every raw
-- component figure, so --from-cache re-renders the two documents from it in
-- well under a second. It cannot recompute the components: those need the
-- routes, and characters.json does not carry them. With no cache present it
-- says so and does the full run instead.

local Cli = dofile("tools/lua/cli.lua")

local json       = dofile("tools/lua/json.lua")
local Characters = dofile("tools/lua/characters.lua")
local Pipeline   = dofile("tools/lua/pipeline.lua")
local PS         = dofile("tools/lua/practicescore.lua")
local Scoring    = require("func/ComboExplorer/core/Scoring")

local TOOL = "practice"

-- Cli.parse wants a value after every --key, so the bare switch gets one,
-- the way all.lua does for --index-only.
local argv = {}
for i, a in ipairs(arg) do
    argv[#argv + 1] = a
    if a == "--from-cache" and arg[i + 1] ~= "true" and arg[i + 1] ~= "false" then
        argv[#argv + 1] = "true"
    end
end

local opt = Cli.args(TOOL, argv, {
    scheme = "modern",
    docs = "docs/ComboExplorer",
    data = "reframework/data/ComboExplorer_data",
    top_n = PS.DEFAULTS.top_n,
    cheap_quantile = PS.DEFAULTS.cheap_quantile,
    comfortable_margin = PS.DEFAULTS.comfortable_margin,
    template = "tools/lua/practice-template.html",
    from_cache = false,
})

if opt.scheme ~= "modern" then
    Cli.die(TOOL, ("--scheme %s: the pipeline only generates modern, so a classic ranking "
        .. "would be a modern ranking under another name."):format(tostring(opt.scheme)))
end

local SCORE_OPTS = {
    top_n = opt.top_n,
    comfortable_margin = opt.comfortable_margin,
    big_motion_digits = PS.DEFAULTS.big_motion_digits,
}

-- --- files -------------------------------------------------------------------

local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local t = f:read("a")
    f:close()
    return t
end

local function write(path, text)
    local f = io.open(path, "wb")
    if not f then return nil, "could not open " .. path end
    f:write(text)
    f:close()
    return #text
end

local CACHE_PATH = opt.docs .. "/practice.json"
local MD_PATH = opt.docs .. "/practice.md"
local HTML_PATH = opt.docs .. "/practice.html"

-- --- gathering ---------------------------------------------------------------

-- characters.json, by lowercase name. The join figures and the worklist
-- confidence split come from here rather than being recomputed: all.lua
-- already publishes them and two tools disagreeing about Guile's join would be
-- worse than either number being wrong.
local function character_index()
    local doc = json.load_file(opt.docs .. "/characters.json")
    local by_lc = {}
    for _, r in ipairs((doc and doc.characters) or {}) do
        if r.lc then by_lc[r.lc] = r end
    end
    return by_lc
end

-- How much of this has been to the game at all, counted rather than asserted.
-- The disclaimer at the top of both documents is built from these numbers, so
-- it cannot drift out of date the way a sentence typed once would.
local function lab_totals(index)
    local t = { characters = 0, with_trials = 0, confirmed = 0, trials = 0, names = {} }
    for _, r in pairs(index) do
        t.characters = t.characters + 1
        if (r.trials or 0) > 0 or (r.combos_confirmed or 0) > 0 then
            t.with_trials = t.with_trials + 1
            t.confirmed = t.confirmed + (r.combos_confirmed or 0)
            t.trials = t.trials + (r.trials or 0)
            t.names[#t.names + 1] = r.character
        end
    end
    table.sort(t.names)
    return t
end

-- "Only Zangief has been to the lab - 7 confirmed combos out of 1000 trials",
-- or whatever the logs actually say today.
local function lab_sentence(lab)
    if not lab or lab.with_trials == 0 then
        return "no character has been to the lab at all"
    end
    return ("only %s %s been to the lab - %d confirmed combo%s out of %d trials")
        :format(table.concat(lab.names, ", "),
            lab.with_trials == 1 and "has" or "have",
            lab.confirmed, lab.confirmed == 1 and "" or "s", lab.trials)
end

-- One character: the pipeline, reduced. Returns summaries, pareto summaries,
-- whether the search was truncated - or nil and a reason.
local function run_character(entry)
    local ctx, err = Pipeline.load({ character = entry.catalog, scheme = opt.scheme })
    if not ctx then return nil, err end
    local gen, gerr = Pipeline.generate(ctx, { drive_rush = false })
    if not gen then return nil, gerr end
    local routes, found = Pipeline.search(ctx, {})
    if not routes then return nil, "no routes" end
    local summaries = PS.route_summaries(routes)
    local pareto = PS.route_summaries(Scoring.pareto(routes))
    local truncated = not (found.stats and found.stats.complete)
    return { summaries = summaries, pareto = pareto, truncated = truncated,
             warnings = ctx.warnings }
end

local function compute()
    local entries, aerr = Characters.all()
    if not entries then Cli.die(TOOL, aerr) end
    local index = character_index()
    local lab = lab_totals(index)

    print(("practice: %d character(s), %s. Running the offline pipeline per character."):format(
        #entries, opt.scheme))

    local per, all_costs, failures = {}, {}, {}
    for i, e in ipairs(entries) do
        local lc = e.catalog:lower()
        io.write(("[%2d/%d] %-10s "):format(i, #entries, e.catalog))
        io.stdout:flush()
        local t0 = os.time()
        local got, gerr = run_character(e)
        if not got then
            print("FAILED: " .. tostring(gerr))
            failures[#failures + 1] = { character = e.catalog, message = tostring(gerr) }
        else
            for _, s in ipairs(got.summaries) do
                if type(s.cost) == "number" then all_costs[#all_costs + 1] = s.cost end
            end
            per[#per + 1] = { entry = e, lc = lc, got = got }
            print(("%5d routes  %2ds%s"):format(#got.summaries, os.time() - t0,
                got.truncated and "  (beam-truncated)" or ""))
        end
        io.stdout:flush()
    end

    -- The cheap-route cut, over every route of every character at once.
    local threshold = PS.quantile(all_costs, opt.cheap_quantile)
    if not threshold then Cli.die(TOOL, "no routes at all - nothing to rank") end
    print(("cheap-route cut: execution_cost <= %.2f  (the %.0fth percentile of %d routes "
        .. "across the roster)"):format(threshold, opt.cheap_quantile * 100, #all_costs))

    local chars = {}
    for _, p in ipairs(per) do
        local row = index[p.lc]
        local wl = json.load_file(("%s/worklist/%s-%s.json"):format(opt.data, p.lc, opt.scheme))
        local raw = {
            easy_damage = PS.easy_damage(p.got.summaries, p.got.pareto, threshold),
            input_shape = PS.input_shape(p.got.summaries, SCORE_OPTS),
            timing_comfort = PS.timing_comfort(wl and wl.pairs, SCORE_OPTS),
            route_availability = PS.route_availability(p.got.summaries),
            data_quality = PS.data_quality(p.got.summaries, row, p.got.truncated, SCORE_OPTS),
        }
        chars[#chars + 1] = {
            character = p.entry.catalog, lc = p.lc, fighter_id = p.entry.fighter_id,
            raw = raw,
        }
    end

    return {
        schema = "ce.practice.v1",
        control_scheme = opt.scheme,
        generated_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        settings = {
            top_n = opt.top_n,
            cheap_quantile = opt.cheap_quantile,
            cheap_threshold = threshold,
            cheap_threshold_routes = #all_costs,
            comfortable_margin = opt.comfortable_margin,
            big_motion_digits = PS.DEFAULTS.big_motion_digits,
            drive_rush = false,
            max_steps = Pipeline.DEFAULTS.max_steps,
            beam = Pipeline.DEFAULTS.beam,
        },
        lab = lab,
        weights = PS.WEIGHTS,
        easy_damage_weights = PS.EASY_DAMAGE_WEIGHTS,
        shape_weights = PS.SHAPE_WEIGHTS,
        quality_weights = PS.QUALITY_WEIGHTS,
        failures = #failures > 0 and failures or nil,
        characters = chars,
    }
end

-- --- formatting --------------------------------------------------------------

local function num(v, digits)
    if type(v) ~= "number" then return "-" end
    return ("%." .. tostring(digits or 0) .. "f"):format(v)
end

local function pct(v, digits)
    if type(v) ~= "number" then return "-" end
    return ("%." .. tostring(digits or 0) .. "f%%"):format(v * 100)
end

local function int(v)
    if type(v) ~= "number" then return "-" end
    return tostring(math.floor(v + 0.5))
end

-- --- the markdown ------------------------------------------------------------

local COMPONENT_ORDER = {
    "easy_damage", "input_shape", "timing_comfort", "route_availability", "data_quality",
}

local WEIGHT_WHY = {
    easy_damage = "A route nobody would use is not practice. A character whose cheap routes "
        .. "already do damage gives a learner something back for the first thing they learn.",
    input_shape = "What the hands actually do - inputs, motion length, grip changes. The only "
        .. "execution signal here that is counted off the notation rather than guessed.",
    timing_comfort = "margin_frames and the mechanism are the closest thing to a link window "
        .. "the data has. Equal to input shape because timing and motion are the two halves of "
        .. "execution and nothing here favours one.",
    route_availability = "Many gauge-free routes means drilling without also learning resource "
        .. "management. Small, because a count of unverified candidates measures the search.",
    data_quality = "A character whose numbers are shaky should not out-rank one whose numbers "
        .. "hold. Small and last, because the join quality is a property of this repo.",
}

local function md_flags(c)
    if not c.flags or #c.flags == 0 then return "-" end
    return table.concat(PS.flag_texts(c.flags), "; ")
end

-- The page is in Japanese and practicescore hands flags over as data, so the
-- same flag is phrased twice rather than printed in the wrong language.
local COMPONENT_JA = {
    ["easy damage"] = "安く出るダメージ",
    ["input shape"] = "入力の形",
    ["timing comfort"] = "タイミングの余裕",
    ["route availability"] = "ルートの数",
    ["data quality"] = "データの確かさ",
}

local function flag_ja(f)
    if f.kind == "weak_join" then
        return ("フレームデータ結合 %d/%d（%.0f%%）"):format(f.matched, f.rows, f.share * 100)
    elseif f.kind == "low_confidence" then
        return ("ワークリストの %.0f%% が low 確度"):format(f.share * 100)
    elseif f.kind == "search_truncated" then
        return "ルート探索が beam 上限で打ち切られた"
    elseif f.kind == "incomplete" then
        local parts = {}
        for i, c in ipairs(f.components) do parts[i] = COMPONENT_JA[c] or c end
        return ("%s は算出できず未採点"):format(table.concat(parts, "・"))
    end
    return tostring(f.kind)
end

-- One sentence about a character, from its own components. Written from the
-- raws rather than the score so it says something checkable.
local function why(c)
    local r, parts = c.raw or {}, {}
    local d, s, t = r.easy_damage, r.input_shape, r.timing_comfort
    if s then
        parts[#parts + 1] = ("its top %d routes by predicted scaled damage average %.1f inputs "
            .. "and %.1f directions in the longest motion, %s of them needing a %d+ direction "
            .. "motion"):format(s.top_n, s.mean_input_count or 0, s.mean_hardest_motion or 0,
                pct(s.big_motion_share), SCORE_OPTS.big_motion_digits)
    end
    if t then
        parts[#parts + 1] = ("%s of its %d worklist pairs are a cancel or a link with %d+ frames "
            .. "of predicted margin (%d of %d links are that comfortable)")
            :format(pct(t.forgiving_share), t.pairs, t.comfortable_margin,
                t.comfortable_links, t.link_pairs)
    end
    if d and d.best_cheap_damage then
        parts[#parts + 1] = ("the best route under the cheap cut predicts %d scaled damage")
            :format(math.floor(d.best_cheap_damage + 0.5))
    end
    return table.concat(parts, "; ") .. "."
end

-- Collects lines. Cli.report() prints as it goes, which is right for
-- explore.lua's short report and wrong for two hundred lines of tables.
local function lines()
    local L = { n = 0 }
    return L, function(fmt, ...)
        L.n = L.n + 1
        L[L.n] = select("#", ...) > 0 and fmt:format(...) or fmt
    end
end

local function render_md(doc, ranked)
    local L, say = lines()
    local st = doc.settings

    say("# Predicted execution ease - %d characters / %s", #ranked, doc.control_scheme)
    say("")
    say("**This is a PREDICTION, not measured difficulty.** It is arithmetic over the frame")
    say("table and the shape of the inputs. Nobody has measured a single link's frame window on")
    say("this build, and %s.", lab_sentence(doc.lab))
    say("There is nothing to calibrate the other %d characters against, and nothing below has",
        #ranked - ((doc.lab and doc.lab.with_trials) or 0))
    say("been run on Street Fighter 6.")
    say("")
    say("Generated by `lua tools/lua/practice.lua`. Do not edit by hand.")
    say("")

    -- --- the ranking
    say("## Ranking - predicted execution ease")
    say("")
    say("Score is 0-100 over the five components below, at the weights in *Weights*. Each")
    say("component is 0-100 as well, min-max normalised across these %d characters, so the top", #ranked)
    say("of a column is the best character here and the bottom is the worst here - not an")
    say("absolute. The components are the point: disagree with the weights and re-read them.")
    say("")
    say("| # | Character | Predicted ease | Easy damage | Input shape | Timing comfort | Route availability | Data quality | Flags |")
    say("|---:|---|---:|---:|---:|---:|---:|---:|---|")
    for _, c in ipairs(ranked) do
        local k = c.components or {}
        say("| %d | %s | **%s** | %s | %s | %s | %s | %s | %s |",
            c.rank, c.character, num(c.score, 1),
            num(k.easy_damage and k.easy_damage * 100, 0),
            num(k.input_shape and k.input_shape * 100, 0),
            num(k.timing_comfort and k.timing_comfort * 100, 0),
            num(k.route_availability and k.route_availability * 100, 0),
            num(k.data_quality and k.data_quality * 100, 0),
            md_flags(c))
    end
    say("")

    -- --- the second view
    say("## Second view - easiest to get real damage cheaply")
    say("")
    say("Component 1 alone, so the composite is not the only reading. A high row here means the")
    say("character's CHEAP routes - execution_cost at or under %.2f, the %.0fth percentile of all",
        st.cheap_threshold, st.cheap_quantile * 100)
    say("%s routes across the roster - already predict good scaled damage, and that the best", int(st.cheap_threshold_routes))
    say("deal on its Pareto front is a good one.")
    say("")
    say("| # | Character | Easy damage | Best cheap route (predicted scaled damage) | Cheap routes | Best damage / cost on the Pareto front | Pareto routes |")
    say("|---:|---|---:|---:|---:|---:|---:|")
    local by_damage = {}
    for _, c in ipairs(ranked) do by_damage[#by_damage + 1] = c end
    table.sort(by_damage, function(a, b) return (a.damage_rank or 0) < (b.damage_rank or 0) end)
    for _, c in ipairs(by_damage) do
        local d = c.raw and c.raw.easy_damage or {}
        say("| %d | %s | %s | %s | %s of %s | %s | %s |",
            c.damage_rank, c.character,
            num(c.components and c.components.easy_damage
                and c.components.easy_damage * 100, 0),
            int(d.best_cheap_damage), int(d.cheap_routes), int(d.routes),
            num(d.best_pareto_ratio, 1), int(d.pareto_routes))
    end
    say("")

    -- --- top and bottom
    say("## The top 3 and the bottom 3, and why")
    say("")
    say("From the components, not from the total. Read these as hypotheses for the sweep.")
    say("")
    for i = 1, math.min(3, #ranked) do
        local c = ranked[i]
        say("%d. **%s** (predicted ease %s) - %s", i, c.character, num(c.score, 1), why(c))
    end
    say("")
    for i = math.max(1, #ranked - 2), #ranked do
        local c = ranked[i]
        say("%d. **%s** (predicted ease %s) - %s", i, c.character, num(c.score, 1), why(c))
    end
    say("")

    -- --- the components, one table each
    say("## Component 1 - easy damage")
    say("")
    say("The best `predicted_damage_scaled` among routes whose `execution_cost` is at or under")
    say("**%.2f**, plus the best damage-per-cost ratio on `Scoring.pareto` (the routes nothing",
        st.cheap_threshold)
    say("else beats on damage and cost at once). The cut is the %.0fth percentile of the pooled",
        st.cheap_quantile * 100)
    say("execution cost of all %s routes, so it is the same cut for everyone and a character can",
        int(st.cheap_threshold_routes))
    say("have none under it. `predicted_damage_scaled` is `core/DamageScaling`'s model, which")
    say("nobody has checked against this build.")
    say("")
    say("| Character | Routes | Cheap routes | Best cheap scaled damage | Pareto routes | Best damage/cost | Mean damage/cost |")
    say("|---|---:|---:|---:|---:|---:|---:|")
    for _, c in ipairs(ranked) do
        local d = c.raw and c.raw.easy_damage or {}
        say("| %s | %s | %s | %s | %s | %s | %s |", c.character,
            int(d.routes), int(d.cheap_routes), int(d.best_cheap_damage),
            int(d.pareto_routes), num(d.best_pareto_ratio, 1), num(d.mean_pareto_ratio, 1))
    end
    say("")

    say("## Component 2 - the input shape of the good routes")
    say("")
    say("Over the top **%d** routes by `predicted_damage_scaled`. A route with no scaled figure", st.top_n)
    say("is left out rather than sorted last: its damage is unknown, not bad. \"4+ motion\" is a")
    say("motion of %d directions or more - 360, 720, 63214 and friends. \"Simple\" is a route with",
        st.big_motion_digits)
    say("at least one Modern SP input in it, which is one button instead of a motion.")
    say("")
    say("| Character | Top routes | Mean inputs | Mean longest motion | 4+ motion | Mean method switches | Uses a simple input |")
    say("|---|---:|---:|---:|---:|---:|---:|")
    for _, c in ipairs(ranked) do
        local s = c.raw and c.raw.input_shape
        if s then
            say("| %s | %d | %s | %s | %s (%d) | %s | %s (%d) |", c.character, s.top_n,
                num(s.mean_input_count, 1), num(s.mean_hardest_motion, 2),
                pct(s.big_motion_share), s.big_motion_routes,
                num(s.mean_method_switches, 2), pct(s.simple_share), s.simple_routes)
        else
            say("| %s | - | - | - | - | - | - |", c.character)
        end
    end
    say("")

    say("## Component 3 - timing comfort (predicted)")
    say("")
    say("Over the committed `worklist/<char>-%s.json` pairs, so every number here can be counted", doc.control_scheme)
    say("out of that file by hand. \"Forgiving\" is a cancel, a pair that is both cancellable and")
    say("linkable, or a link whose `margin_frames` is **%d or more**. A cancel window is", st.comfortable_margin)
    say("generally wider than a link and the sweep times the two differently (be1c0be), so the")
    say("mechanism is the first cut and the margin is the second. An `unknown` pair - the frame")
    say("join had no numbers for it - counts against the forgiving share, which does mean this")
    say("column carries some of the same information as component 5.")
    say("")
    say("| Character | Pairs | Cancel | Both | Link | Unknown | Comfortable links (%d+f) | Tight links (1-2f) | Forgiving share |", st.comfortable_margin)
    say("|---|---:|---:|---:|---:|---:|---:|---:|---:|")
    for _, c in ipairs(ranked) do
        local t = c.raw and c.raw.timing_comfort
        if t then
            say("| %s | %d | %d | %d | %d | %d | %d (%s) | %d (%s) | %s |", c.character,
                t.pairs, t.cancel_pairs, t.both_pairs, t.link_pairs, t.unknown_pairs,
                t.comfortable_links, pct(t.comfortable_link_share),
                t.tight_links, pct(t.tight_link_share), pct(t.forgiving_share, 1))
        else
            say("| %s | - | - | - | - | - | - | - | - |", c.character)
        end
    end
    say("")

    say("## Component 4 - route availability")
    say("")
    say("How much there is to practise at all, and how much of it needs no meter. \"No gauge\" is")
    say("computed here straight from the `offline_score` fields - `od_steps`, `super_steps` and")
    say("`drive_rush_cancel_steps` all zero - and **not** from planner.lua's no-gauge preset,")
    say("which is another tool's definition. Drive Rush Cancel edges are not in this search at")
    say("all, so `drive_rush_cancel_steps` is zero everywhere and only OD and super rule routes")
    say("out. The count is log-scaled before normalising, because the roster spans 454 to 2681.")
    say("")
    say("| Character | Routes | 3-move routes | No-gauge routes | No-gauge share | 3-move and no gauge |")
    say("|---|---:|---:|---:|---:|---:|")
    for _, c in ipairs(ranked) do
        local a = c.raw and c.raw.route_availability
        if a then
            say("| %s | %d | %d | %d | %s | %d |", c.character, a.routes, a.three_move_routes,
                a.no_gauge_routes, pct(a.no_gauge_share), a.three_move_no_gauge_routes)
        else
            say("| %s | - | - | - | - | - |", c.character)
        end
    end
    say("")

    say("## Component 5 - data quality")
    say("")
    say("How much of the row above rests on numbers that are actually there. The join and the")
    say("confidence split are `characters.json`'s own figures, so they agree with the index")
    say("page. The guessed-join share is over the same top %d routes as component 2. A truncated", st.top_n)
    say("search is a flag rather than a penalty: the beam cuts the search short for most of the")
    say("roster, so a penalty would be a penalty on nearly everyone.")
    say("")
    say("| Character | Frame-data join | Worklist pairs | Low confidence | Guessed join (top routes) | Search truncated |")
    say("|---|---:|---:|---:|---:|---|")
    for _, c in ipairs(ranked) do
        local q = c.raw and c.raw.data_quality
        if q then
            say("| %s | %s of %s (%s) | %s | %s (%s) | %s of %s steps (%s) | %s |", c.character,
                int(q.join_matched), int(q.join_rows), pct(q.join_share),
                int(q.worklist_pairs), int(q.low_confidence_pairs), pct(q.low_confidence_share),
                int(q.guessed_join_steps), int(q.top_steps), pct(q.guessed_join_share),
                q.search_truncated and "yes" or "no")
        else
            say("| %s | - | - | - | - | - |", c.character)
        end
    end
    say("")

    -- --- method and weights
    say("## Method")
    say("")
    say("1. `tools/lua/pipeline.lua` runs explore.lua's own settings for each of the %d", #ranked)
    say("   characters: modern, midscreen, no counter-hit, at most %d moves, beam %d, Drive Rush",
        st.max_steps, st.beam)
    say("   Cancel edges excluded. Each route is reduced to the dozen numbers in")
    say("   `practicescore.route_summary`.")
    say("2. Every route's `execution_cost` goes into one pooled list; its %.0fth percentile is",
        st.cheap_quantile * 100)
    say("   the cheap-route cut, **%.2f**.", st.cheap_threshold)
    say("3. The five components are computed per character as the tables above describe. Each")
    say("   one keeps the count it came from, so it can be checked.")
    say("4. Each component's signals are **min-max normalised across the characters present**:")
    say("   0 is the worst character in this set on that signal and 1 the best. Route counts are")
    say("   log-scaled first. Min-max rather than a z-score because several signals are skewed")
    say("   by one or two characters - Guile's 2797 worklist pairs, Dhalsim's 2681 routes - and")
    say("   a z-score over a skewed distribution reads as a precise claim about a distribution")
    say("   that is not normal. Two consequences: the bottom of every column is 0 by")
    say("   construction, and dropping a character moves everyone else.")
    say("5. The components are combined at the weights below. A component that could not be")
    say("   computed is **dropped and the remaining weights renormalised**, and the character is")
    say("   flagged - never scored zero, which would be a claim about the character rather than")
    say("   about the data.")
    say("")
    say("## Weights")
    say("")
    say("Tunable in `tools/lua/practicescore.lua`. They are published so a reader can disagree")
    say("with them; the component columns above are there so the disagreement can be acted on")
    say("without rerunning anything.")
    say("")
    say("| Component | Weight | Why |")
    say("|---|---:|---|")
    for _, k in ipairs(COMPONENT_ORDER) do
        say("| %s | %.2f | %s |", PS.COMPONENT_LABELS[k], doc.weights[k], WEIGHT_WHY[k])
    end
    say("")
    say("Inside the components:")
    say("")
    say("- **easy damage**: best cheap scaled damage %.2f, best Pareto damage/cost %.2f.",
        doc.easy_damage_weights.best_cheap_damage, doc.easy_damage_weights.best_pareto_ratio)
    say("- **input shape**: mean inputs %.2f, mean longest motion %.2f, 4+ motion share %.2f, "
        .. "mean method switches %.2f, simple-input share %.2f (the only one where higher is easier).",
        doc.shape_weights.mean_input_count, doc.shape_weights.mean_hardest_motion,
        doc.shape_weights.big_motion_share, doc.shape_weights.mean_method_switches,
        doc.shape_weights.simple_share)
    say("- **timing comfort**: one signal, the forgiving share.")
    say("- **route availability**: one signal, log of the no-gauge route count.")
    say("- **data quality**: frame-data join %.2f, confident share %.2f, exact-join share %.2f.",
        doc.quality_weights.join_share, doc.quality_weights.confident_share,
        doc.quality_weights.exact_join_share)
    say("")

    -- --- the disclaimer that matters
    say("## What this cannot see")
    say("")
    say("- **No measured link windows.** Not one. `margin_frames` is a subtraction over two")
    say("  frame-table rows, and `core/Scoring.lua` says it plainly: a one-frame link and a")
    say("  six-frame link look identical from here. Everything called \"comfortable\" above is a")
    say("  prediction about a window nobody has swept.")
    say("- **Almost nothing has been to the lab.** Of these %d characters, %s.", #ranked,
        lab_sentence(doc.lab))
    say("  Every other character has zero trials, so there is nothing to calibrate against.")
    say("- **Combos are not a character.** Nothing here is about anti-airs, okizeme, movement,")
    say("  neutral, defence, resource management, or any matchup. A character that is easy to")
    say("  combo with can still be a hard character to play, and the reverse.")
    say("- **Modern only.** The pipeline generates modern and excludes Classic rows from")
    say("  probing, so a Classic player's answer is not in this table.")
    say("- **Beam-truncated searches.** The route search hits its beam limit for most of the")
    say("  roster. The routes it did not reach are not in any component, and they are not")
    say("  random - the beam keeps what looked good early.")
    say("- **Damage scaling is an unverified model.** `predicted_damage_scaled` comes from")
    say("  `core/DamageScaling`, built from public write-ups and never checked against this")
    say("  build. It is used for ordering and must not be read as damage.")
    say("- **The routes are candidates.** Every route in every component is a sequence the frame")
    say("  data says is worth a trial. None of them is known to combo.")
    say("- **Min-max is relative.** A 0 in a column means \"last of these %d\", not \"none\".", #ranked)
    say("")
    if doc.failures then
        say("## Characters that did not run")
        say("")
        for _, f in ipairs(doc.failures) do say("- %s: %s", f.character, f.message) end
        say("")
    end
    say("Page version: [practice.html](practice.html). Numbers: `practice.json`. Generated %s.",
        doc.generated_at)
    return table.concat(L, "\n") .. "\n"
end

-- --- the page ----------------------------------------------------------------

local function html_escape(s)
    return (tostring(s):gsub("[&<>\"']", {
        ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;", ["'"] = "&#39;",
    }))
end
local H = html_escape

-- Literal replacement: string.gsub would read a % in the text as a capture.
local function fill(template, marker, text)
    local at = template:find(marker, 1, true)
    if not at then return nil, "the template has no " .. marker .. " marker" end
    return template:sub(1, at - 1) .. text .. template:sub(at + #marker)
end

-- A cell that sorts on a number and displays something else. data-sort is what
-- the page's sorter reads, so "-" sorts as nothing rather than as text.
-- data-label is what the phone layout puts in front of the value.
local function cell(label, sort_value, body, class)
    local attr = (type(sort_value) == "number")
        and (' data-sort="%.6f"'):format(sort_value) or ' data-sort=""'
    return ('<td data-label="%s"%s%s>%s</td>')
        :format(H(label), attr, class and (' class="' .. class .. '"') or "", body)
end

local function bar(v)
    if type(v) ~= "number" then return '<span class="muted">-</span>' end
    return ('<div class="barwrap"><div class="bar" style="width:%.1f%%"></div>'
        .. '<span class="barn num">%d</span></div>'):format(v * 100, math.floor(v * 100 + 0.5))
end

local function render_html(template, doc, ranked)
    local st = doc.settings
    local rows = {}
    for _, c in ipairs(ranked) do
        local k = c.components or {}
        local r = c.raw or {}
        local d, s, t, a, q = r.easy_damage, r.input_shape, r.timing_comfort,
            r.route_availability, r.data_quality
        local flags = ""
        if c.flags and #c.flags > 0 then
            local li = {}
            for _, f in ipairs(c.flags) do li[#li + 1] = "<li>" .. H(flag_ja(f)) .. "</li>" end
            flags = '<ul class="notes">' .. table.concat(li) .. "</ul>"
        else
            flags = '<span class="muted">-</span>'
        end
        rows[#rows + 1] = table.concat({
            "<tr>",
            cell("#", c.rank, ('<span class="rank num">%d</span>'):format(c.rank), "r"),
            cell("キャラ", nil, ('<div class="who">%s</div><div class="sub mono">#%s</div>')
                :format(H(c.character), H(tostring(c.fighter_id or "?"))), "who-cell"),
            cell("予測ラクさ", c.score, ('<b class="num">%s</b>'):format(num(c.score, 1)), "n score"),
            cell("① 安く出るダメージ", k.easy_damage, bar(k.easy_damage) ..
                ('<small>最安ルート %s / 比 %s</small>')
                :format(int(d and d.best_cheap_damage), num(d and d.best_pareto_ratio, 1)), "n"),
            cell("② 入力の形", k.input_shape, bar(k.input_shape) ..
                ('<small>入力 %s · 最長モーション %s · 4+ %s</small>')
                :format(num(s and s.mean_input_count, 1), num(s and s.mean_hardest_motion, 2),
                        pct(s and s.big_motion_share)), "n"),
            cell("③ タイミングの余裕", k.timing_comfort, bar(k.timing_comfort) ..
                ('<small>猶予あり %s · リンク %s/%s が %df 以上</small>')
                :format(pct(t and t.forgiving_share), int(t and t.comfortable_links),
                        int(t and t.link_pairs), st.comfortable_margin), "n"),
            cell("④ ルートの数", k.route_availability, bar(k.route_availability) ..
                ('<small>ゲージ不要 %s / %s ルート</small>')
                :format(int(a and a.no_gauge_routes), int(a and a.routes)), "n"),
            cell("⑤ データの確かさ", k.data_quality, bar(k.data_quality) ..
                ('<small>結合 %s · low %s</small>')
                :format(pct(q and q.join_share), pct(q and q.low_confidence_share)), "n"),
            cell("① 単独順位", c.damage_rank,
                ('<span class="num">%d 位</span>'):format(c.damage_rank or 0), "n"),
            cell("注意", nil, flags, "notes-cell"),
            "</tr>",
        })
    end

    local tiles = {}
    local function tile(label, value, sub)
        tiles[#tiles + 1] = ('<div class="tile"><div class="eyebrow">%s</div>'
            .. '<div class="big num">%s</div><div class="muted sub">%s</div></div>')
            :format(H(label), value, sub)
    end
    local top = ranked[1]
    local bottom = ranked[#ranked]
    local flagged = 0
    for _, c in ipairs(ranked) do if c.flags and #c.flags > 0 then flagged = flagged + 1 end end
    local lab = doc.lab or { with_trials = 0, names = {}, confirmed = 0, trials = 0 }
    tile("キャラクター", tostring(#ranked), "Modern のみ · 全員が予測値")
    tile("実機で試したキャラ", tostring(lab.with_trials),
        lab.with_trials > 0
            and H(("%s（確定 %d / 試行 %d）"):format(table.concat(lab.names, ", "),
                lab.confirmed, lab.trials))
            or "まだ 1 キャラもない")
    tile("予測ラク 1位", top and H(top.character) or "-",
        top and ("スコア " .. num(top.score, 1)) or "")
    tile("予測ラク 最下位", bottom and H(bottom.character) or "-",
        bottom and ("スコア " .. num(bottom.score, 1)) or "")
    tile("注意つき", tostring(flagged), "数字が弱いキャラ")

    local page, err = fill(template, "<!--__TILES__-->", table.concat(tiles, "\n"))
    if not page then return nil, err end
    page, err = fill(page, "<!--__LAB__-->", H(lab.with_trials > 0
        and ("実機に持ち込んだのは %s だけ（試行 %d 回・確定コンボ %d）。残り %d キャラには照らし合わせる実測がありません。")
            :format(table.concat(lab.names, ", "), lab.trials, lab.confirmed,
                #ranked - lab.with_trials)
        or "実機に持ち込んだキャラはまだ 1 体もありません。"))
    if not page then return nil, err end
    page, err = fill(page, "<!--__ROWS__-->", table.concat(rows, "\n"))
    if not page then return nil, err end
    page, err = fill(page, "<!--__SETTINGS__-->", H(
        ("実行コストの「安い」しきい値 %.2f（全 %d ルートの第 %.0f 百分位）· 上位 %d ルートで入力形状を集計 · "
            .. "リンクの余裕 %d フレーム以上を「余裕あり」· 最大 %d 技 · beam %d · DRC 抜き · 生成 %s")
        :format(st.cheap_threshold, st.cheap_threshold_routes, st.cheap_quantile * 100,
                st.top_n, st.comfortable_margin, st.max_steps, st.beam, doc.generated_at)))
    if not page then return nil, err end
    return page
end

-- --- the run -----------------------------------------------------------------

local started = os.time()
local doc

if opt.from_cache then
    doc = json.load_file(CACHE_PATH)
    if not doc or not doc.characters or #doc.characters == 0 then
        print(("practice: no usable cache at %s - the components need the per-route scores, "
            .. "which characters.json does not carry, so this is a full run."):format(CACHE_PATH))
        doc = compute()
    else
        print(("practice: re-rendering from %s (%d characters, generated %s). The components "
            .. "were not recomputed."):format(CACHE_PATH, #doc.characters,
                tostring(doc.generated_at)))
    end
else
    doc = compute()
end

local ranked = PS.rank(doc.characters, { weights = doc.weights })

Cli.mkdir(opt.docs)
json.save_file(CACHE_PATH, doc, { indent = "  " })

local md = render_md(doc, ranked)
local n, werr = write(MD_PATH, md)
if not n then Cli.die(TOOL, werr) end

local template = read(opt.template)
if not template then Cli.die(TOOL, "no page template at " .. opt.template) end
local page, perr = render_html(template, doc, ranked)
if not page then Cli.die(TOOL, perr) end
write(HTML_PATH, page)

print("")
print(("written: %s, %s, %s"):format(MD_PATH, HTML_PATH, CACHE_PATH))
print(("predicted-ease top 3: %s"):format(table.concat({
    ranked[1] and ranked[1].character or "-",
    ranked[2] and ranked[2].character or "-",
    ranked[3] and ranked[3].character or "-",
}, ", ")))
print(("elapsed: %ds"):format(os.time() - started))
os.exit(0)
