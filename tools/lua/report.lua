-- =========================================================
-- tools/lua/report.lua - every trial the game has run for one character, drawn
-- on one page.
--
--   lua tools/lua/report.lua [--character Zangief] [--scheme modern]
--                            [--data reframework/data/ComboExplorer_data]
--                            [--out docs/ComboExplorer/sweep-report-<char>-<scheme>.html]
--                            [--no-drive-rush] [--summary <path.json>]
--
-- Needs Lua 5.4 and the logs the sweep wrote. No game, no network. The page it
-- writes is self-contained: open it in a browser, or publish it as it is.
-- =========================================================
--
-- WHAT IT READS
--
--   worklist/<char>-<scheme>.json   the pairs, and so the grid's two axes
--   trials/<char>-*.jsonl           every log for the character, one per experiment
--   route/*.json                    route definitions, to name a route log's steps
--   command_display/<Character>.json   classic notation, so a combo reads the way
--                                      players write it
--
-- WHAT IT WRITES
--
--   the page                        --out
--   docs/ComboExplorer/combos-<char>-<scheme>.md   the combo list on its own,
--                                      readable on GitHub without opening the page
--
-- Every log is read, not the latest one. The logs are a sequence of
-- experiments - delay 4, then the gap from the frame data, then the whole
-- notation group - and a later one exists because of what an earlier one
-- showed. The page lets a reader flip between them for the same reason.
--
-- Run it again after a session on the game and commit the page with the logs.

local Cli = dofile("tools/lua/cli.lua")

local json        = dofile("tools/lua/json.lua")
local Characters  = dofile("tools/lua/characters.lua")
local SweepReport = dofile("tools/lua/sweepreport.lua")

local opt = Cli.args("report", arg, {
    character = "Zangief",
    scheme = "modern",
    data = "reframework/data/ComboExplorer_data",
    template = "tools/lua/report-template.html",
    drive_rush = true,
})

local entry, cerr = Characters.resolve(opt.character)
if not entry then Cli.die("report", tostring(cerr)) end
local char_lc = entry.catalog:lower()
opt.out = opt.out or ("docs/ComboExplorer/sweep-report-%s-%s.html"):format(char_lc, opt.scheme)

local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local text = f:read("a")
    f:close()
    return text
end

-- --- the worklist -------------------------------------------------------------

local wl_path = ("%s/worklist/%s-%s.json"):format(opt.data, char_lc, opt.scheme)
local worklist, werr = json.load_file(wl_path)
if not worklist then
    Cli.die("report", ("no worklist at %s (%s)\n\nThe grid's axes are the worklist's pairs, "
        .. "so there is nothing to draw without one."):format(wl_path, tostring(werr)))
end

-- --- the logs -----------------------------------------------------------------

-- Same rule as confirm.lua: a line that will not decode is counted, not dropped.
-- It is a trial that ran and whose result was lost.
local function read_log(path)
    local text = read(path)
    if not text then return nil end
    local records, bad = {}, 0
    for line in text:gmatch("[^\r\n]+") do
        local ok, rec = pcall(json.decode, line)
        if ok and type(rec) == "table" then
            records[#records + 1] = rec
        else
            bad = bad + 1
        end
    end
    return records, bad
end

local logs = {}
local prefix = char_lc .. "-"
for _, name in ipairs(Cli.list_dir(opt.data .. "/trials")) do
    if name:sub(1, #prefix) == prefix and name:match("%.jsonl$") then
        local path = ("%s/trials/%s"):format(opt.data, name)
        local records, bad = read_log(path)
        if records then
            logs[#logs + 1] = { name = name:gsub("%.jsonl$", ""), path = path,
                                records = records, bad_lines = bad }
        end
    end
end

local routes = {}
for _, name in ipairs(Cli.list_dir(opt.data .. "/route")) do
    if name:match("%.json$") then
        local doc = json.load_file(("%s/route/%s"):format(opt.data, name))
        if type(doc) == "table" and doc.id then routes[doc.id] = doc end
    end
end

-- --- build and write ---------------------------------------------------------

-- Classic notation is a label here, nothing more. A catalog that cannot be read
-- leaves the list in the notation the sweep pressed, which is still correct.
local classic = {}
do
    local catalog = json.load_file(Characters.catalog_path(entry))
    if type(catalog) == "table" then
        for id, row in pairs(catalog) do
            local cc = type(row) == "table" and row.classic_command
            if type(cc) == "table" and type(cc.display) == "string" then
                classic[tonumber(id) or id] = cc.display
            end
        end
    end
end

local model = SweepReport.build(worklist, logs, routes, classic)
model.generated_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
model.sources = { worklist = wl_path, data = opt.data }

-- --- the two rules a combo can be confirmed under ---------------------------------
--
-- The list above counts a link wherever it happened: any input method, any
-- cohort, any gap, and a row from a file that was re-run after a defect was
-- fixed counts beside the re-run's. That is "which combos has this game ever
-- shown me", and it is worth keeping - it is the only list that says a combo
-- has been SEEN.
--
-- It is not the list the lab database publishes. tools/lua/labeval.lua's policy
-- ce-eval-v1 counts a run only when it asked the question (no fixed gap 4
-- inside A's animation, no link timing on a cancel-only pair, no button pressed
-- a motion's worth of ticks late, no input today's compiler would refuse), and
-- leaves out a superseded re-run unless it linked. A pair is confirmed when
-- ConfirmedEdge calls it stable on what is left; a route when at least
-- SweepReport.CONFIRM_LINKS of its counted runs linked.
--
-- Both go on the page, each labelled with the rule it passed, and the headline
-- is the policy's. Two numbers with no rule beside them is what made the page
-- say seven where the database said six.
local Pipeline  = dofile("tools/lua/pipeline.lua")
local Planner   = dofile("tools/lua/planner.lua")
local LabKnown  = dofile("tools/lua/labknown.lua")
local LabRows   = dofile("tools/lua/labrows.lua")
local RouteView = dofile("tools/lua/routeview.lua")

local function load_pipeline()
    local ctx, lerr = Pipeline.load({ character = entry.catalog, scheme = opt.scheme })
    if not ctx then error(tostring(lerr), 0) end
    -- Generated once, with the Drive Rush Cancel edges. The plain edges are the
    -- same either way (explore.lua's --drive-rush promise), and a plain search
    -- only ever reads the plain ones.
    local gen, gerr = Pipeline.generate(ctx, { drive_rush = opt.drive_rush ~= false })
    if not gen then error(tostring(gerr), 0) end
    return { ctx = ctx, gen = gen }
end

local ok_pipe, pipe = pcall(load_pipeline)
local pipeline_error = (not ok_pipe) and tostring(pipe) or nil
if not ok_pipe then pipe = nil end

-- The trial rows as tools/db/lab-import.mjs builds them, and the evaluations
-- ce-eval-v1 makes of them. Needs the catalog and the generator for a pair's
-- mechanism and notations, and nothing else: a page whose pipeline would not
-- load keeps the looser list and says the policy could not be applied.
local function policy_view()
    local ctx = pipe and pipe.ctx
    if not ctx then error(pipeline_error or "no catalog", 0) end
    local notation_of = {}
    for _, row in ipairs(ctx.cat.rows) do
        notation_of[("%s:%s"):format(row.action_id, row.input_method)] = row.notation
    end
    local files = LabKnown.load_trials(opt.data, char_lc, Cli.list_dir)
    local lookup = LabKnown.lookup(entry.catalog, opt.scheme,
        LabRows.pair_index(ctx.plain_edges, pipe.gen and pipe.gen.excluded,
                           Pipeline.edge_pair_key),
        notation_of, routes)
    local evaluations, problems, policy, counts = LabKnown.from_files(files, lookup, {
        keep = function(rec)
            return rec.control_scheme == nil or rec.control_scheme == opt.scheme
        end,
    })
    return { evaluations = evaluations, problems = problems, policy = policy,
             counts = counts, notation_of = notation_of,
             exclusions = LabKnown.exclusions(evaluations) }
end

local ok_pol, pol = pcall(policy_view)
if not ok_pol then
    model.policy_error = tostring(pol)
    pol = nil
end

-- The whole known set, folded once: the page's chips, the combo labels and the
-- finder all read it, and two foldings of the same logs would be two answers.
--
-- Both readings go in. The evaluations decide every status the page shows; the
-- raw ConfirmedEdge fold is kept beside them so a pair the policy has no
-- evaluation for still appears, and so `raw_status` is there to compare against.
-- With no policy (no catalog) the raw fold is all there is, which is the page
-- this was before ce-eval-v1.
local ConfirmedEdge = require("func/ComboExplorer/core/ConfirmedEdge")
local records = {}
for _, log in ipairs(logs) do
    for _, rec in ipairs(log.records) do
        if rec.control_scheme == nil or rec.control_scheme == opt.scheme then
            records[#records + 1] = rec
        end
    end
end
local known = Planner.known_from(ConfirmedEdge.from_trials(records), model.combos,
    pol and pol.notation_of or nil, pol and pol.evaluations or nil)

-- Every combo the looser list holds, labelled with what the policy made of the
-- same moves. `policy = nil` on a row means no counted run is about it at all.
local policy_confirmed, policy_seen = 0, 0
for _, c in ipairs(model.combos) do
    local names = (c.inputs or {})[1]
    local t = Planner.combo_policy_of(known, c.key, names and table.concat(names, ">") or nil)
    if t then
        c.policy = {
            status = t.status, result = t.result,
            links = t.successes, failures = t.failures,
            unanswered = t.unanswered, excluded = t.excluded,
            excluded_negatives = t.excluded_negatives, cohorts = t.cohorts,
        }
        if t.status == Planner.KNOWN.VERIFIED then policy_confirmed = policy_confirmed + 1
        elseif t.successes and t.successes > 0 then policy_seen = policy_seen + 1 end
    end
end

if pol then
    local pairs_confirmed, routes_confirmed = 0, 0
    for _, ev in ipairs(pol.evaluations) do
        if ev.result == "reproduced" then
            if ev.subject_kind == "edge" then pairs_confirmed = pairs_confirmed + 1
            else routes_confirmed = routes_confirmed + 1 end
        end
    end
    local by_status = {}
    for _, k in pairs(known.pairs) do
        by_status[k.status] = (by_status[k.status] or 0) + 1
    end
    model.policy = {
        key = pol.policy and pol.policy.key, version = pol.policy and pol.policy.version,
        description = pol.policy and pol.policy.description,
        runs = pol.exclusions.counted + pol.exclusions.excluded,
        counted = pol.exclusions.counted, excluded = pol.exclusions.excluded,
        excluded_negatives = pol.exclusions.negatives_excluded,
        by_reason = pol.exclusions.by_reason,
        evaluations = #pol.evaluations,
        -- lab.confirmed_combos: an evaluation whose result is `reproduced`,
        -- counted per subject per cohort, pairs and routes apart.
        confirmed_pairs = pairs_confirmed, confirmed_routes = routes_confirmed,
        confirmed_combos = policy_confirmed, seen_combos = policy_seen,
        pairs_by_status = by_status,
        problems = #(pol.problems or {}),
    }
end

-- --- the route finder -----------------------------------------------------------
--
-- Every candidate route explore.lua finds, with what the logs say about each of
-- its pairs, so the page can narrow them by condition - a starter, no gauge -
-- and show which pairs are still unanswered for the routes that are left.
--
-- The page filters; it does not decide. Every verdict a condition needs is
-- computed here by tools/lua/planner.lua's own filters and shipped as a value,
-- so "no gauge" on the page is exactly plan.lua's --no-gauge, including the
-- routes it keeps on a gap. The page is for looking; plan.lua writes the
-- worklist, and the page prints the command that would.
--
-- Optional. The route search needs the frame data under data/, which the page
-- can live without: a report run where it is missing still draws the map and
-- the combo list, and says why the finder is empty.
local function route_finder()
    local InputMask = require("func/ComboExplorer/core/InputMask")

    if not pipe then return nil, pipeline_error end
    local ctx = pipe.ctx
    if not ctx.idx then return nil, ctx.warnings[1] end
    local all, found = Pipeline.search(ctx, {})

    local function verdict(r, cond)
        local kept, rep = Planner.filter({ r }, cond)
        if not kept or #kept == 0 then return "remove" end
        return next(rep.flags) and "flag" or "keep"
    end

    local rows, starters, seen_starter = {}, {}, {}

    local function add_rows(ranked)
        local anns = Planner.annotate(nil, ranked, known).routes
        for i, r in ipairs(ranked) do
            local s = r.offline_score or {}
            local moves = Planner.moves(r)
            local modern, classic_names, drc_after = {}, {}, {}
            local mi = 0
            for _, st in ipairs(r.steps or {}) do
                if st.kind == "drive_rush_cancel" then
                    drc_after[#drc_after + 1] = mi
                elseif st.kind == nil then
                    mi = mi + 1
                    modern[mi] = st.notation
                    classic_names[mi] = st.classic or classic[st.action_id]
                end
            end
            local first = moves[1] or {}
            local parsed = InputMask.parse(first.notation or "")
            if first.notation and not seen_starter[first.notation] then
                seen_starter[first.notation] = true
                starters[#starters + 1] = first.notation
            end

            local a = anns[i]
            local pairs_out = {}
            for pi, p in ipairs(Planner.route_pairs(r)) do
                local press = SweepReport.press_kind(p.b.notation)
                local press_a = SweepReport.press_kind(p.a.notation)
                if press == "single" and press_a ~= "single" and pi == 1 then press = press_a end
                -- A pair through a rush keys as "A->drc->B", planner.lua's key,
                -- which is the key a DRC trial would be recorded under.
                pairs_out[pi] = { k = p.key, st = a.pair_statuses[pi], press = press,
                                  drc = p.drc or nil }
            end

            rows[#rows + 1] = {
                m = modern, c = classic_names, drc_after = drc_after,
                sd = s.predicted_damage_scaled, d = s.predicted_damage,
                dc = s.predicted_damage_complete,
                od = s.od_steps, sa = s.super_steps, drc = s.drive_rush_cancel_steps,
                cost = s.execution_cost,
                starter = { n = first.notation, b = parsed and parsed.buttons or {} },
                no_gauge = verdict(r, { no_gauge = true }),
                no_super = verdict(r, { no_super = true }),
                pairs = pairs_out, rej = a.has_rejected_pair or nil,
                -- `confirmed` is the policy's rule (lab.confirmed_combos);
                -- `combo` is the looser list's, kept beside it so a reader can
                -- see a combo the game has linked that the policy did not count.
                confirmed = a.confirmed or nil, combo = a.combo_status,
                combo_policy = a.combo_policy,
            }
        end
    end

    local ranked, rinfo = Planner.rank(all, "scaled_damage")
    add_rows(ranked)
    local plain_total = #rows

    -- Drive Rush Cancel routes, as extra rows.
    --
    -- A second search over plain and DRC edges together - the one plan.lua runs
    -- with --drive-rush - keeping only its routes that actually go through a
    -- rush. Its plain routes are not taken: they are a beam-trimmed subset of
    -- the search above (Zangief: 742 of 917), and two different lists of the
    -- same routes on one page would disagree about which exist. The rush routes
    -- ride behind the plain ones, ranked among themselves, and the page shows
    -- them only when its DRC box is ticked.
    --
    -- Measured before choosing this over a separate route set: the second search
    -- costs about twice the first (Guile, the slowest, 11s) and adds 500-1500
    -- rows, which packed come to less than the per-pair grid a page with no logs
    -- no longer embeds.
    local drc_info
    if opt.drive_rush ~= false then
        local ok, droutes, dfound = pcall(Pipeline.search, ctx, { drive_rush = true })
        if ok then
            local only = {}
            for _, r in ipairs(droutes) do
                if ((r.offline_score or {}).drive_rush_cancel_steps or 0) > 0 then
                    only[#only + 1] = r
                end
            end
            add_rows((Planner.rank(only, "scaled_damage")))
            drc_info = { total = #only, edges = #(ctx.drc_edges or {}),
                         complete = dfound.stats.complete }
        else
            drc_info = { error = tostring(droutes) }
        end
    end

    local packed = RouteView.compact(rows)
    return {
        moves = packed.moves, pairs = packed.pairs, rows = packed.rows,
        starters = starters, total = plain_total,
        complete = found.stats.complete,
        drc = drc_info,
        sort_field = rinfo.field, sort_fallback = rinfo.fallback or nil,
        scaling_model = ranked[1] and ranked[1].offline_score
            and ranked[1].offline_score.scaling_model or nil,
    }
end

local ok_rf, finder, ferr = pcall(route_finder)
if ok_rf and finder then
    model.routes_view = finder
else
    model.routes_view_error = tostring(ok_rf and ferr or finder)
end

-- --- what a page with no trials does not need --------------------------------
--
-- The grid draws one cell per worklist pair and colours it from a log. With no
-- pair log there is nothing to colour, and a grid of 2,800 empty cells says
-- less than one sentence does, so the page collapses the map to that sentence
-- and the per-pair table is not embedded: for Guile it was 505KB of a 1.1MB
-- page. What the sentence needs - the pair count, the starters and targets,
-- what can be pressed - stays.
if #model.pair_logs == 0 then
    model.pairs_omitted = true
    model.pairs = json.EMPTY_OBJECT
end

local template = read(opt.template)
if not template then Cli.die("report", "no page template at " .. opt.template) end

-- "</" is escaped so no string in the data - a reason, a note - can close the
-- script element it is embedded in.
local payload = json.encode(model):gsub("</", "<\\/")
local marker = "/*__MODEL__*/null"
local at = template:find(marker, 1, true)
if not at then Cli.die("report", "the template has no " .. marker .. " marker") end
local page = template:sub(1, at - 1) .. payload .. template:sub(at + #marker)
local title = ("%s %s 接続マップ"):format(entry.catalog,
    opt.scheme == "modern" and "Modern" or opt.scheme)
page = page:gsub("__TITLE__", function() return title end, 1)

local f = io.open(opt.out, "wb")
if not f then Cli.die("report", "could not write " .. opt.out) end
f:write(page)
f:close()

-- --- what was drawn ---------------------------------------------------------

-- --- the combo list, on its own ------------------------------------------------

local combos_path = opt.combos
    or ("docs/ComboExplorer/combos-%s-%s.md"):format(char_lc, opt.scheme)

local function chain(names, sep)
    return table.concat(names, sep or " → ")
end

local md = {}
local function line(fmt, ...)
    md[#md + 1] = select("#", ...) > 0 and fmt:format(...) or fmt
end

local confirmed, once = {}, {}
for _, c in ipairs(model.combos) do
    if c.status == SweepReport.COMBO.CONFIRMED then confirmed[#confirmed + 1] = c
    else once[#once + 1] = c end
end

local function classic_of(c)
    local names = {}
    for i, s in ipairs(c.steps) do names[i] = s.classic or "?" end
    return chain(names)
end

local POLICY_MD = {
    verified = "確定", linked_once = "1回だけ", rejected = "繋がらなかった",
    asked_badly = "質問できていない", pending = "未回答",
}

local function policy_cell(c)
    local p = c.policy
    if not p then return "対象外" end
    return ("%s（数えた試行 繋がった %d・否定 %d・未回答 %d／除外 %d）")
        :format(POLICY_MD[p.status] or p.status, p.links or 0, p.failures or 0,
                p.unanswered or 0, p.excluded or 0)
end

local function combo_rows(list)
    line("| コンボ（Modern） | Classic | 方針 %s | 繋がった | 試行の内訳 | 繋がった隙間 (tick) | ダメージ |",
        tostring(model.policy and model.policy.key or "（未適用）"))
    line("|---|---|---|---|---|---|---|")
    for _, c in ipairs(list) do
        local inputs = {}
        for i, names in ipairs(c.inputs) do inputs[i] = chain(names) end
        -- Unanswered is shown apart from negative: most of it is an earlier
        -- experiment whose inputs never came out, not the combo failing.
        local damage = "未計測"
        if c.damage_measured then
            damage = c.damage_min == c.damage_max and tostring(c.damage_min)
                or ("%d–%d"):format(c.damage_min, c.damage_max)
            if (c.damage_disagreements or 0) > 0 then
                damage = damage .. (" (体力差と不一致 %d)"):format(c.damage_disagreements)
            end
        end
        line("| %s | %s | %s | %d 回 | 試行 %d・否定 %d・未回答 %d | %s | %s |",
            table.concat(inputs, "<br>"), classic_of(c), policy_cell(c), c.links, c.attempts,
            c.negatives, c.unanswered, table.concat(c.linked_gaps, ", "), damage)
    end
end

line("# %s %s — 繋がったコンボ", entry.catalog, opt.scheme == "modern" and "Modern" or opt.scheme)
line("")
line("`lua tools/lua/report.lua` が試行ログから書き出す一覧です。手で編集しないでください —")
line("実機でログが増えたら、同じコマンドで書き直します。")
line("")
line("二つの規則が並んでいます。見出しの分け方はログの緩いほうの規則、`方針` の列は")
line("データベースが公開している規則です。")
line("")
line("- **ログ上の確定**: どこかで %d 回以上繋がった。入力方法・コホート・隙間をまたいで数え、",
    SweepReport.CONFIRM_LINKS)
line("  欠陥が見つかって再実行されたファイルの行も数えます。「ゲームがこれを見せた」という一覧です")
line("- **方針 `%s`**: 質問になっていない試行を数えません（gap 4 で A の動作中に押した、",
    tostring(model.policy and model.policy.key or "ce-eval-v1"))
line("  キャンセル専用のペアを A の回復後に押した、B のボタンがコマンド分だけ遅れた、")
line("  今のコンパイラでは押せない入力。再実行で置き換えられた行は繋がった場合だけ数えます）。")
line("  残った試行で ConfirmedEdge が stable と言えばペアは確定、ルートは数えた試行で %d 回繋がれば確定",
    SweepReport.CONFIRM_LINKS)
line("- **ダメージ**は繋がった試行で測った `mComboDamage`。この記録を始める前のログには無く「未計測」になります。公開用の `ce.verified_combo.v1` は実測ダメージを必須にしています（#17, #36）")
line("")
if model.policy then
    local p = model.policy
    line("方針が数えた試行 %d / 全 %d（除外 %d、うち否定 %d）。`lab.confirmed_combos` は被験体で",
        p.counted, p.runs, p.excluded, p.excluded_negatives)
    line("数えるのでペア %d + ルート %d = %d 件、この一覧は技で束ねるので %d 行が確定です。",
        p.confirmed_pairs, p.confirmed_routes, p.confirmed_pairs + p.confirmed_routes,
        p.confirmed_combos)
else
    line("**方針を適用できませんでした**（%s）ので、`方針` の列は空です。",
        tostring(model.policy_error))
end
line("")
line("## ログ上の確定 (%d)", #confirmed)
line("")
if #confirmed > 0 then combo_rows(confirmed) else line("まだありません。") end
line("")
line("## ログ上は1回だけ繋がった (%d)", #once)
line("")
if #once > 0 then combo_rows(once) else line("ありません。") end
line("")
line("生成: %s", model.generated_at)

do
    local mf = io.open(combos_path, "wb")
    if not mf then Cli.die("report", "could not write " .. combos_path) end
    mf:write(table.concat(md, "\n"), "\n")
    mf:close()
end

local rep = Cli.report()
rep:say("# Sweep report - %s / %s", entry.catalog, opt.scheme)
rep:say("")
rep:say("worklist pairs   %d  (pressable %d / repeated direction %d / follow-up %d)",
    model.worklist.count, model.press.single, model.press["repeat"], model.press.followup)
rep:say("combos           %d confirmed / %d seen once  (the looser list: any input "
    .. "method, cohort or gap)", #confirmed, #once)
if model.policy then
    local p = model.policy
    rep:say("policy %-10s %d of %d runs counted (%d excluded, %d of them negatives)",
        tostring(p.key), p.counted, p.runs, p.excluded, p.excluded_negatives)
    rep:say("                 confirmed: %d pair(s) + %d route(s) = %d subject(s), %d row(s) here",
        p.confirmed_pairs, p.confirmed_routes, p.confirmed_pairs + p.confirmed_routes,
        p.confirmed_combos)
else
    rep:say("policy           not applied: %s", tostring(model.policy_error))
end
for _, c in ipairs(confirmed) do
    rep:say("  %-40s  %s  (%d/%d)  policy: %s", chain(c.inputs[1]), classic_of(c),
        c.links, c.attempts, c.policy and tostring(c.policy.result) or "no counted run")
end
for _, l in ipairs(model.pair_logs) do
    local v = l.counts.verdicts
    rep:say("pair log   %-36s %4d rows  link %d / combo_broke %d / whiff %d / wrong_move %d / other-pairs %d",
        l.name, l.counts.rows, v.link or 0, v.combo_broke or 0, v.whiff or 0, v.wrong_move or 0,
        l.counts.elsewhere)
end
for _, l in ipairs(model.route_logs) do
    rep:say("route log  %-36s %4d rows  link %d", l.name, l.counts.rows, l.counts.verdicts.link or 0)
end
local rv = model.routes_view
if rv then
    rep:say("route finder     %d routes%s", rv.total,
        rv.drc and (rv.drc.error and ("  (DRC search failed: " .. rv.drc.error .. ")")
            or ("  + %d through a Drive Rush Cancel"):format(rv.drc.total)) or "")
else
    rep:say("route finder     none: %s", tostring(model.routes_view_error))
end
rep:say("")
rep:say("written: %s (%d bytes)", opt.out, #page)
rep:say("written: %s", combos_path)

-- --- the batch's numbers ------------------------------------------------------
--
-- tools/lua/all.lua runs this for every character and builds the index page
-- from what each run says here, rather than by reading the page back.
if opt.summary then
    local trials, bad_lines = 0, 0
    for _, l in ipairs(logs) do
        trials = trials + #l.records
        bad_lines = bad_lines + (l.bad_lines or 0)
    end
    local summary = {
        schema = "ce.report_summary.v1",
        character = entry.catalog, control_scheme = opt.scheme,
        page = opt.out, page_bytes = #page, combos_md = combos_path,
        worklist_pairs = model.worklist.count,
        press = model.press,
        logs = #logs, pair_logs = #model.pair_logs, route_logs = #model.route_logs,
        trials = trials, unreadable_lines = bad_lines,
        combos_confirmed = #confirmed, combos_once = #once,
        policy = model.policy, policy_error = model.policy_error,
        pairs_embedded = not model.pairs_omitted,
        routes = rv and rv.total or nil,
        routes_complete = rv and rv.complete,
        routes_drc = rv and rv.drc and rv.drc.total or nil,
        drc_error = rv and rv.drc and rv.drc.error or nil,
        finder_error = model.routes_view_error,
    }
    local n, serr = json.save_file(opt.summary, summary, { indent = "  " })
    if not n then Cli.die("report", ("could not write %s: %s"):format(opt.summary, tostring(serr))) end
end
