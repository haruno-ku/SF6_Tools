-- =========================================================
-- tools/lua/batch.lua - the pure half of tools/lua/all.lua: which characters,
-- what the per-character runs said, and the pages built from it.
-- Dev-machine only, like the rest of tools/.
-- =========================================================
--
-- WHY IT IS SPLIT
--
-- all.lua starts processes, waits for them and copies files; none of that has a
-- test worth writing. What does is everything that turns their output into a
-- number somebody reads: the parse of explore's report, the weak-character
-- notes, the index page and the pair-count table in the runbook. A parse that
-- silently read 0 routes for every character would publish an index that says
-- 31 characters have nothing to try, and it would look entirely plausible.
--
-- Nothing here touches the filesystem. Text in, tables and text out.

local M = { name = "tools.batch" }

-- --- what the batch runs -------------------------------------------------------

-- The plans written for every character. The three Zangief was planned with,
-- by the names his plan files already have, so a regenerated Zangief overwrites
-- his own plans rather than adding a second copy under another name.
M.PRESETS = {
    { name = "max-damage", label = "最大ダメージ", args = { "--sort", "scaled_damage", "--top", "20" } },
    { name = "no-gauge", label = "ノーゲージ", args = { "--no-gauge", "--top", "20" } },
    { name = "starter-chu", label = "中始動", args = { "--starter-button", "M", "--top", "20" } },
}

-- --- the priority character ---------------------------------------------------------
--
-- One character the offline pipeline is tuned for, because somebody is actually
-- practising with them. Everything below is what "priority" buys, and the index
-- page says the same three things in the same order:
--
--   1. a deeper search (M.DEEP), run to completion rather than cut by the beam
--   2. the practice presets (M.PRACTICE_PRESETS) beside the three standard ones
--   3. route files the game can run, for the practice presets' best routes
--
-- Nothing here changes what the other 30 characters get. A deep run costs about
-- 15 seconds a plan against 4, and six presets instead of three, so one deep
-- character adds roughly a minute and a half to a batch that runs four lanes in
-- parallel - the batch stays the three to five minutes it was.
M.DEFAULT_PRIORITY = "Ryu"

-- MEASURED on Ryu (551 candidate edges), Lua 5.4, one lane:
--
--   beam  4000, max 3 moves   1092 routes, INCOMPLETE (334 partials dropped)   4s
--   beam 20000, max 3 moves   1126 routes, complete                            5s
--   beam 20000, max 4 moves   3528 routes, INCOMPLETE (15462 dropped)         12s
--   beam 60000, max 4 moves   4538 routes, complete                           13s
--
-- 60000/4 is the first setting that finishes: no partial route is dropped and
-- no route goes unemitted, so "4538" is every route the generation rules can
-- reach rather than a sample of them. It is chosen for that and not for being
-- big - a deeper search that still truncates would leave the route list exactly
-- as unreliable as the default one, and the reader could not tell.
M.DEEP = { beam = 60000, max_steps = 4 }

-- A plan preset's `args` can name a value the batch computes rather than one
-- written here. Today only the cheap-route cut, which is a measurement OF THE
-- WHOLE ROSTER (tools/lua/practicescore.lua's 25th percentile of every scored
-- route's execution_cost, which tools/lua/practice.lua writes into
-- practice.json as settings.cheap_threshold). Writing 6.00 here would freeze
-- last month's roster into a preset.
M.VAR = { CHEAP_CUT = "@cheap-cut" }

-- Plans for LEARNING a character, as against the three above, which are for
-- finding the strongest thing on the list. Run for the priority character only.
--
-- Each says what a person would be asking for out loud, and the conditions are
-- the whole of the answer - nothing is hand-picked afterwards.
M.PRACTICE_PRESETS = {
    {
        name = "easy-damage", label = "簡単・高火力", routes = 3,
        why = "no gauge, and only routes the roster's own cheap cut calls cheap to "
            .. "execute, ordered by predicted scaled damage. The most damage available "
            .. "from the easy half of what this character can do.",
        args = { "--no-gauge", "--max-execution-cost", M.VAR.CHEAP_CUT,
                 "--sort", "scaled_damage", "--top", "20" },
    },
    {
        name = "hit-confirm", label = "ヒット確認", routes = 3,
        why = "the first pair is a cancel (or a cancel with a link window beside it) "
            .. "off a light or medium starter - the shape you can start, see hit, and "
            .. "then finish. A link there is a window you commit to blind.",
        args = { "--first-pair-mechanism", "cancel,both", "--starter-buttons", "L,M",
                 "--sort", "scaled_damage", "--top", "20" },
    },
    {
        name = "no-gauge-3", label = "ノーゲージ3段", routes = 3,
        why = "exactly three moves and no OD, no Super and no Drive Rush Cancel: the "
            .. "bread-and-butter length, with nothing spent, ordered by predicted "
            .. "scaled damage.",
        args = { "--no-gauge", "--min-steps", "3", "--max-steps", "3",
                 "--sort", "scaled_damage", "--top", "20" },
    },
}

-- Every preset a character gets, standard first. `practice` marks the ones only
-- the priority character runs, so a caller does not have to know the two lists.
function M.presets_for(is_priority)
    local out = {}
    for _, p in ipairs(M.PRESETS) do out[#out + 1] = p end
    if is_priority then
        for _, p in ipairs(M.PRACTICE_PRESETS) do out[#out + 1] = p end
    end
    return out
end

-- A preset's args with the batch's variables substituted.
--
-- Returns args, or nil and the name of the variable nothing supplied. Refused
-- rather than dropped: a preset that quietly lost its cost cut would run as
-- "every no-gauge route", produce a plan, and look right.
function M.preset_args(preset, vars)
    local out = {}
    for _, a in ipairs(preset.args or {}) do
        if type(a) == "string" and a:sub(1, 1) == "@" then
            local v = (vars or {})[a]
            if v == nil then return nil, a end
            out[#out + 1] = tostring(v)
        else
            out[#out + 1] = a
        end
    end
    return out
end

-- The extra arguments a deep run adds to explore.lua and plan.lua. The two
-- tools spell the search depth differently: explore's --max-steps IS the depth,
-- plan's --max-steps is a condition on route length and its depth is
-- --search-steps. Getting that backwards would run plan.lua at depth 3 with a
-- "at most 4 moves" condition that removes nothing.
-- report.lua takes the same two keys as plan.lua, for the same reason: its own
-- --max-steps would be ambiguous next to a condition of that name on the page.
function M.deep_args(tool)
    if tool == "explore" then
        return { "--beam", tostring(M.DEEP.beam), "--max-steps", tostring(M.DEEP.max_steps) }
    elseif tool == "plan" or tool == "report" then
        return { "--beam", tostring(M.DEEP.beam), "--search-steps", tostring(M.DEEP.max_steps) }
    end
    return {}
end

-- Modern only, and no longer because classic cannot be built.
--
-- `explore.lua --scheme classic` now builds a real classic catalog and a real
-- classic worklist - Catalog.build reads classic_command, the frame-data join
-- is the same join it always was, and the routes come out. What it cannot do is
-- be swept: not one of the six Classic buttons has a measured pl_input_new bit
-- on this build (Provenance.classic_button_bits), so runtime/Sweep.lua sets
-- every classic pair aside by name before the first trial.
--
-- A batch that generated classic pages would therefore publish a full set of
-- documents for a scheme with zero confirmed rows in it, beside a Modern set
-- with real ones, and the two would look like the same kind of thing. When the
-- calibration has been run under Classic, add it here.
M.SCHEMES = { modern = true }

-- Seconds a sweep trial takes, for the runbook's "one pass" column. RUNBOOK.md's
-- own figure ("1試行およそ3秒").
M.SECONDS_PER_TRIAL = 3

-- --- choosing characters --------------------------------------------------------

-- "Ryu, zangief,5" -> entries, in the bridge's fighter order, duplicates folded.
-- resolve : Characters.resolve. all : Characters.all().
-- nil or "" means every character. An unknown name is an error, not a skip: a
-- typo that quietly ran nothing would print a clean summary of nothing.
function M.select(only, all, resolve)
    if only == nil or only == "" or only == true then return all end
    local want, bad = {}, {}
    for part in tostring(only):gmatch("[^,]+") do
        local name = part:match("^%s*(.-)%s*$")
        if name ~= "" then
            local e, err = resolve(name)
            if e then want[e.catalog] = true else bad[#bad + 1] = tostring(err) end
        end
    end
    if #bad > 0 then return nil, table.concat(bad, "\n") end
    local out = {}
    for _, e in ipairs(all) do
        if want[e.catalog] then out[#out + 1] = e end
    end
    if #out == 0 then return nil, "--only named no character" end
    return out
end

-- Round-robin into n lanes, each run by one process, so the long characters
-- (Guile, Juri, DeeJay are close together in fighter order) spread out.
function M.lanes(list, n)
    if #list == 0 then return {} end
    n = math.max(1, math.min(n or 1, #list))
    local lanes = {}
    for i = 1, n do lanes[i] = {} end
    for i, x in ipairs(list) do
        local l = lanes[(i - 1) % n + 1]
        l[#l + 1] = x
    end
    return lanes
end

-- --- starting a process -----------------------------------------------------------

local function quote(s)
    s = tostring(s)
    if s:match('^[%w%._/:%-\\]+$') then return s end
    return '"' .. s:gsub('"', '\\"') .. '"'
end
M.quote = quote

-- One command line: exe, arguments, and both streams to a log file.
--
-- On Windows os.execute and io.popen hand the line to `cmd /c`, which strips
-- the first and last quote of the whole line when it starts with one - so
-- `"C:\Program Files\lua.exe" x > "log"` loses the quote before C: and the one
-- after log. Wrapping the line in one more pair is the documented way round.
function M.command(exe, args, log, windows)
    local parts = { quote(exe) }
    for _, a in ipairs(args or {}) do parts[#parts + 1] = quote(a) end
    local line = table.concat(parts, " ")
    if log then line = line .. " > " .. quote(log) .. " 2>&1" end
    if windows and line:sub(1, 1) == '"' then line = '"' .. line .. '"' end
    return line
end

-- --- reading what the runs said ----------------------------------------------------

local function num(text, pattern)
    local v = text:match(pattern)
    return v and tonumber(v) or nil
end

-- explore.lua's report, as far as the index needs it. Returns a table whose
-- fields are nil when the line is absent - never 0 - so a changed report shows
-- up as a missing number rather than as a character with nothing in it.
function M.parse_explore_report(text)
    if type(text) ~= "string" or text == "" then return nil end
    local r = {}
    r.catalog_rows = num(text, "\n%- catalog rows%s+(%d+)")
    r.starters = num(text, "\n%- starting moves%s+(%d+)")
    r.targets = num(text, "\n%- target moves%s+(%d+)")
    local matched, rows = text:match("\n%- frame data coverage%s+(%d+) of%s+(%d+)")
    if matched then r.coverage_all = { matched = tonumber(matched), rows = tonumber(rows) } end
    -- The coverage a note is taken on is starters and targets only. The overall
    -- figure includes derivations measured with no parent, which join to nothing
    -- on every character by construction (survey.lua says why), so Zangief -
    -- 14/14 starters, 33/33 targets - would read as a weak join at 89%.
    local sm, sr = text:match("\n%s+starters%s+(%d+) of%s+(%d+)")
    local tm, tr = text:match("\n%s+targets%s+(%d+) of%s+(%d+)")
    if sm and tm then
        r.coverage = { matched = tonumber(sm) + tonumber(tm), rows = tonumber(sr) + tonumber(tr) }
    else
        r.coverage = r.coverage_all
    end
    r.frame_data = text:find("\n%- frame data: NONE") == nil
    r.candidates = num(text, "\n%- candidate edges%s+(%d+)")
    r.excluded = num(text, "\n## Theoretical edges.-\n%- excluded%s+(%d+)")
    r.drc_edges = num(text, "\n%- DRC edges%s+(%d+)")
    r.routes = num(text, "\n%- routes%s+(%d+)")
    local complete = text:match("\n%- search complete%s+(%a+)")
    if complete then r.search_complete = (complete == "true") end
    return r
end

-- { high, medium, low } over a ce.worklist.v1's pairs.
function M.confidence_counts(doc)
    local c = { high = 0, medium = 0, low = 0 }
    for _, p in ipairs((doc and doc.pairs) or {}) do
        if c[p.confidence] then c[p.confidence] = c[p.confidence] + 1 end
    end
    return c
end

-- One character's row in the index, from the pieces all.lua read back.
--   entry    : the bridge entry
--   explore  : parse_explore_report, or nil
--   worklist : the main ce.worklist.v1, or nil
--   drc      : the -drc worklist, or nil
--   plans    : { [preset name] = plan worklist doc }
--   summary  : report.lua's ce.report_summary.v1, or nil
--   errors   : { { step, message } }
--   opts     : { priority = true, route_files = N }, for the priority character.
--              The deep search's own numbers are not passed - they are read off
--              the plans, which carry what the search actually did.
function M.row(entry, scheme, explore, worklist, drc, plans, summary, errors, opts)
    local lc = entry.catalog:lower()
    local row = {
        character = entry.catalog, fighter_id = entry.fighter_id, lc = lc,
        control_scheme = scheme,
        catalog_rows = explore and explore.catalog_rows,
        frame_data = explore and explore.frame_data,
        coverage = explore and explore.coverage,
        candidates = explore and explore.candidates,
        drc_edges = explore and explore.drc_edges,
        worklist_pairs = worklist and worklist.count or nil,
        worklist_confidence = worklist and M.confidence_counts(worklist) or nil,
        drc_pairs = drc and drc.count or nil,
        plans = {},
        routes = summary and summary.routes or (explore and explore.routes),
        routes_complete = summary and summary.routes_complete,
        routes_drc = summary and summary.routes_drc,
        trials = summary and summary.trials,
        logs = summary and summary.logs,
        combos_confirmed = summary and summary.combos_confirmed,
        combos_once = summary and summary.combos_once,
        unpressable = summary and summary.press
            and ((summary.press["repeat"] or 0) + (summary.press.followup or 0)
                 + (summary.press.unreadable or 0)) or nil,
        page = summary and ("sweep-report-%s-%s.html"):format(lc, scheme) or nil,
        page_bytes = summary and summary.page_bytes,
        finder_error = summary and summary.finder_error,
        drc_error = summary and summary.drc_error,
        offline_report = explore and ("%s-offline-report.md"):format(lc) or nil,
        errors = (errors and #errors > 0) and errors or nil,
    }
    for _, p in ipairs(M.PRESETS) do
        local doc = plans and plans[p.name]
        row.plans[p.name] = doc and doc.count or nil
    end
    opts = opts or {}
    if opts.priority then
        row.priority = true
        row.practice_plans = {}
        for _, p in ipairs(M.PRACTICE_PRESETS) do
            local doc = plans and plans[p.name]
            row.practice_plans[p.name] = doc and doc.count or nil
            -- The search settings the plan actually ran under, taken from the
            -- first practice plan that carries them rather than from M.DEEP:
            -- what the constant says and what the run did are two things, and
            -- the index should print the one that happened.
            local s = doc and doc.plan and doc.plan.search
            if s and not row.deep then
                row.deep = { beam = s.beam, max_steps = s.max_steps,
                             complete = s.complete, routes = doc.plan.available }
            end
        end
        row.route_files = opts.route_files
    end
    row.notes = M.notes(row)
    return row
end

-- What makes a character's numbers weaker than they look. Each note is a short
-- sentence the index prints beside the character; an empty list means nothing
-- stood out, not that the character has been checked on the game.
function M.notes(row)
    local out = {}
    for _, e in ipairs(row.errors or {}) do
        out[#out + 1] = ("%s が失敗: %s"):format(tostring(e.step), tostring(e.message))
    end
    if row.frame_data == false then
        out[#out + 1] = "フレームデータなし: 候補はすべて low 確度"
    elseif row.coverage and row.coverage.rows > 0 then
        local r = row.coverage.matched / row.coverage.rows
        if r < 0.9 then
            out[#out + 1] = ("始動・対象技のフレームデータ結合 %d/%d (%.0f%%): 残りは数字のない候補")
                :format(row.coverage.matched, row.coverage.rows, r * 100)
        end
    end
    local c, n = row.worklist_confidence, row.worklist_pairs
    if c and n and n > 0 and c.low / n >= 0.6 then
        out[#out + 1] = ("ワークリストの %.0f%% が low 確度"):format(c.low / n * 100)
    end
    -- An incomplete route search is not a note: explore's beam cuts the search
    -- short for most characters, and a note on nearly every row hides the ones
    -- that say something. It is marked on the route count instead.
    if row.finder_error then out[#out + 1] = "ルート検索なし: " .. tostring(row.finder_error) end
    if row.drc_error then out[#out + 1] = "DRC ルートなし: " .. tostring(row.drc_error) end
    for _, p in ipairs(M.PRESETS) do
        if row.plans and row.plans[p.name] == 0 then
            out[#out + 1] = ("プラン %s に確かめるペアがない"):format(p.name)
        end
    end
    for _, p in ipairs(M.PRACTICE_PRESETS) do
        if row.practice_plans and row.practice_plans[p.name] == 0 then
            out[#out + 1] = ("練習プラン %s に確かめるペアがない"):format(p.name)
        end
    end
    -- On the priority character an incomplete search IS a note. The whole point
    -- of the deeper run is that the route list is all of them; if it still cuts
    -- short, the one row on this page whose numbers could be trusted cannot be.
    if row.priority and row.deep and row.deep.complete == false then
        out[#out + 1] = ("優先キャラだが探索が打ち切られた (beam %s, 最大 %s 手): ルート一覧は一部")
            :format(tostring(row.deep.beam), tostring(row.deep.max_steps))
    end
    return out
end

-- The priority character first, then everybody else in the order given. A row
-- pinned to the top of a 31-row table is the only placement a reader does not
-- have to be told about.
function M.priority_first(rows)
    local top, rest = {}, {}
    for _, r in ipairs(rows or {}) do
        if r.priority then top[#top + 1] = r else rest[#rest + 1] = r end
    end
    for _, r in ipairs(rest) do top[#top + 1] = r end
    return top
end

-- Rows from this run replace the same characters' rows from the last one; the
-- rest are kept, so `--only Ryu` rebuilds the index for 31 characters rather
-- than for one. Returned in fighter order.
function M.merge_rows(old, new)
    local by = {}
    for _, r in ipairs(old or {}) do by[r.character] = r end
    for _, r in ipairs(new or {}) do by[r.character] = r end
    local out = {}
    for _, r in pairs(by) do out[#out + 1] = r end
    table.sort(out, function(a, b)
        if (a.fighter_id or 0) ~= (b.fighter_id or 0) then return (a.fighter_id or 0) < (b.fighter_id or 0) end
        return a.character < b.character
    end)
    return out
end

function M.totals(rows)
    local t = { characters = #rows, worklist_pairs = 0, drc_pairs = 0, routes = 0, routes_drc = 0,
                combos_confirmed = 0, trials = 0, tried = 0, failed = 0, page_bytes = 0 }
    for _, r in ipairs(rows) do
        t.worklist_pairs = t.worklist_pairs + (r.worklist_pairs or 0)
        t.drc_pairs = t.drc_pairs + (r.drc_pairs or 0)
        t.routes = t.routes + (r.routes or 0)
        t.routes_drc = t.routes_drc + (r.routes_drc or 0)
        t.combos_confirmed = t.combos_confirmed + (r.combos_confirmed or 0)
        t.trials = t.trials + (r.trials or 0)
        t.page_bytes = t.page_bytes + (r.page_bytes or 0)
        if (r.trials or 0) > 0 then t.tried = t.tried + 1 end
        if r.errors then t.failed = t.failed + 1 end
    end
    return t
end

-- --- formatting ------------------------------------------------------------------

-- 324 pairs -> "約16分"; 2888 -> "約2.4時間". The runbook's own spelling.
function M.pass_time(pairs_n, seconds_per_trial)
    if not pairs_n then return "-" end
    local s = pairs_n * (seconds_per_trial or M.SECONDS_PER_TRIAL)
    local minutes = s / 60
    if minutes < 59.5 then
        return ("約%d分"):format(math.floor(minutes + 0.5))
    end
    local h = math.floor(s / 360 + 0.5) / 10
    local text = ("%.1f"):format(h):gsub("%.0$", "")
    return ("約%s時間"):format(text)
end

function M.bytes(n)
    if not n then return "-" end
    if n >= 1024 * 1024 then return ("%.1f MB"):format(n / 1024 / 1024) end
    return ("%d KB"):format(math.floor(n / 1024 + 0.5))
end

-- 1234567 -> "1,234,567"
function M.thousands(n)
    if n == nil then return "-" end
    local s = tostring(math.tointeger(n) or n)
    local sign, int, rest = s:match("^(%-?)(%d+)(.*)$")
    if not int then return s end
    int = int:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return sign .. int .. rest
end

local function dash(v) return v == nil and "-" or tostring(v) end

-- The table all.lua prints at the end.
function M.summary_lines(rows, timings)
    local lines = {}
    local head = ("%-9s %5s %6s %6s %6s %5s %5s %5s %5s %5s %6s %6s  %s")
        :format("char", "rows", "cands", "routes", "+drc", "pairs", "drc", "maxd", "nog", "chu",
                "page", "secs", "status")
    lines[1] = head
    lines[2] = ("-"):rep(#head + 8)
    for _, r in ipairs(rows) do
        local status = r.errors and ("FAILED: " .. table.concat((function()
            local s = {}
            for _, e in ipairs(r.errors) do s[#s + 1] = e.step end
            return s
        end)(), ", ")) or "ok"
        lines[#lines + 1] = ("%-9s %5s %6s %6s %6s %5s %5s %5s %5s %5s %6s %6s  %s"):format(
            r.character, dash(r.catalog_rows), dash(r.candidates), dash(r.routes), dash(r.routes_drc),
            dash(r.worklist_pairs), dash(r.drc_pairs),
            dash(r.plans and r.plans["max-damage"]), dash(r.plans and r.plans["no-gauge"]),
            dash(r.plans and r.plans["starter-chu"]),
            r.page_bytes and M.bytes(r.page_bytes):gsub(" ", "") or "-",
            timings and timings[r.character] and ("%.0f"):format(timings[r.character]) or "-",
            status)
    end
    return lines
end

-- --- the index page ------------------------------------------------------------------

function M.html(s)
    return (tostring(s):gsub("[&<>\"']", {
        ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;", ["'"] = "&#39;",
    }))
end
local H = M.html

-- Replaces a marker with text, literally. string.gsub would read % in the text
-- as a capture reference, and a note can contain "90%".
function M.fill(template, marker, text)
    local at = template:find(marker, 1, true)
    if not at then return nil, "the template has no " .. marker .. " marker" end
    return template:sub(1, at - 1) .. text .. template:sub(at + #marker)
end

local function conf_bar(c, n)
    if not c or not n or n == 0 then return '<span class="muted">-</span>' end
    local function seg(k)
        local w = c[k] / n * 100
        return ('<span class="c-%s" style="width:%.1f%%"></span>'):format(k, w)
    end
    return ('<div class="conf" role="img" aria-label="high %d、medium %d、low %d">%s%s%s</div>'
        .. '<div class="conf-n num">%d · %d · %d</div>')
        :format(c.high, c.medium, c.low, seg("high"), seg("medium"), seg("low"),
                c.high, c.medium, c.low)
end

local function td(label, body, class)
    return ('<td data-label="%s"%s>%s</td>'):format(H(label), class and (' class="' .. class .. '"') or "", body)
end

local function n_or_dash(v)
    return v == nil and '<span class="muted">-</span>' or M.thousands(v)
end

function M.index_rows_html(rows)
    local out = {}
    for _, r in ipairs(M.priority_first(rows)) do
        local name = r.page
            and ('<a href="%s">%s</a>'):format(H(r.page), H(r.character))
            or H(r.character)
        local state
        if r.errors then
            state = '<span class="badge fail">失敗</span>'
        elseif (r.combos_confirmed or 0) > 0 then
            state = ('<span class="badge ok">確定 %d</span>'):format(r.combos_confirmed)
        elseif (r.trials or 0) > 0 then
            state = '<span class="badge tried">試行あり</span>'
        else
            state = '<span class="badge open">未試行</span>'
        end
        local plans = {}
        for _, p in ipairs(M.PRESETS) do
            local v = r.plans and r.plans[p.name]
            plans[#plans + 1] = ('<span class="plan" title="%s"><i>%s</i> %s</span>')
                :format(H(p.name), H(p.label), v == nil and "-" or tostring(v))
        end
        for _, p in ipairs(M.PRACTICE_PRESETS) do
            local v = r.practice_plans and r.practice_plans[p.name]
            if v ~= nil or r.priority then
                plans[#plans + 1] = ('<span class="plan practice" title="%s - %s"><i>%s</i> %s</span>')
                    :format(H(p.name), H(p.why), H(p.label), v == nil and "-" or tostring(v))
            end
        end
        local notes = ""
        if r.notes and #r.notes > 0 then
            local li = {}
            for _, n in ipairs(r.notes) do li[#li + 1] = "<li>" .. H(n) .. "</li>" end
            notes = '<ul class="notes">' .. table.concat(li) .. "</ul>"
        end
        local routes = n_or_dash(r.routes)
        if r.routes_complete == false then
            routes = routes .. '<abbr class="cut" title="探索が beam の上限で打ち切られた。載っていないルートがある">*</abbr>'
        end
        if r.routes_drc then routes = routes .. ('<small>+DRC %s</small>'):format(M.thousands(r.routes_drc)) end
        if r.priority and r.deep then
            routes = routes .. ('<small class="deep">beam %s · 最大 %s 手%s</small>')
                :format(M.thousands(r.deep.beam), tostring(r.deep.max_steps),
                        r.deep.complete and " · 完走" or " · 打ち切り")
        end
        local who = ('<div class="who">%s</div><div class="sub mono">#%s</div>')
            :format(name, dash(r.fighter_id))
        if r.priority then
            who = '<div class="pri-badge" title="優先キャラ: 探索を深く、練習プランあり、ルートファイル生成済み">'
                .. '優先</div>' .. who
        end
        out[#out + 1] = table.concat({
            r.priority and '<tr class="pri">' or "<tr>",
            td("キャラ", who, "who-cell"),
            td("状態", state),
            td("ワークリスト", ('<b class="num">%s</b><small>1パス %s</small>')
                :format(n_or_dash(r.worklist_pairs), H(M.pass_time(r.worklist_pairs))), "n"),
            td("確度 high · med · low", conf_bar(r.worklist_confidence, r.worklist_pairs)),
            td("DRC ペア", n_or_dash(r.drc_pairs), "n"),
            td("候補ルート", routes, "n"),
            td("プラン（ペア数）", '<div class="plans">' .. table.concat(plans) .. "</div>"),
            td("確定 / 試行", ('%s<small>試行 %s</small>')
                :format(n_or_dash(r.combos_confirmed), n_or_dash(r.trials)), "n"),
            td("注意", notes ~= "" and notes or '<span class="muted">-</span>', "notes-cell"),
            "</tr>",
        })
    end
    return table.concat(out, "\n")
end

function M.index_totals_html(t)
    local function tile(label, value, sub)
        return ('<div class="tile"><div class="eyebrow">%s</div><div class="big num">%s</div>%s</div>')
            :format(H(label), value, sub and ('<div class="muted sub">' .. sub .. "</div>") or "")
    end
    return table.concat({
        tile("キャラクター", tostring(t.characters),
            ("実機ログあり %d%s"):format(t.tried, t.failed > 0 and (" · 失敗 %d"):format(t.failed) or "")),
        tile("ワークリスト", M.thousands(t.worklist_pairs), "ペア · スイープが押す候補"),
        tile("DRC ペア", M.thousands(t.drc_pairs), "まだ押せない · 別ファイル"),
        tile("候補ルート", M.thousands(t.routes), ("+ DRC 経由 %s"):format(M.thousands(t.routes_drc))),
        tile("確定コンボ", M.thousands(t.combos_confirmed), ("試行 %s 回から"):format(M.thousands(t.trials))),
    }, "\n")
end

-- The paragraph that says what the badge on the top row means. Empty when no
-- row is the priority character: an explanation of a badge nobody can see is
-- worse than no explanation.
function M.priority_note_html(rows)
    local pri
    for _, r in ipairs(rows or {}) do
        if r.priority then pri = r break end
    end
    if not pri then return "" end
    local deep = pri.deep
    local search = deep
        and ("beam %s・最大 %s 手で探索し、%s（候補ルート %s）")
            :format(M.thousands(deep.beam), tostring(deep.max_steps),
                    deep.complete and "打ち切りなしで完走" or "それでも打ち切られた",
                    n_or_dash(deep.routes))
        or ("beam %s・最大 %s 手"):format(M.thousands(M.DEEP.beam), tostring(M.DEEP.max_steps))
    local names = {}
    for _, p in ipairs(M.PRACTICE_PRESETS) do names[#names + 1] = p.name end
    return table.concat({
        '<div class="priority-note">',
        ('<b>優先キャラ: %s</b> — 実際に練習している 1 人だけ、オフラインの扱いを厚くしています。'):format(H(pri.character)),
        "<ol>",
        ("<li>深い探索: %s。ほかの 30 キャラは既定のまま（beam 4,000・最大 3 手）です。</li>"):format(H(search)),
        ("<li>練習用プラン: 通常の 3 プリセットに加えて <code>%s</code>。覚えるための条件で絞ったものです。</li>")
            :format(H(table.concat(names, "</code>, <code>"))),
        ("<li>ルートファイル: 練習プランの上位ルートを %s に書き出し済み。ゲーム側の ROUTE から走らせられます。</li>")
            :format(pri.route_files and ("%d 本"):format(pri.route_files) or "route/"),
        "</ol>",
        '<p class="muted" style="margin:6px 0 0">優先キャラでも、オフラインで出る数字はすべて予測です。'
            .. '実機で確かめた回数は上の表の「確定 / 試行」列が示します。</p>',
        "</div>",
    }, "\n")
end

function M.render_index(template, rows)
    local t = M.totals(rows)
    local page, err = M.fill(template, "<!--__TOTALS__-->", M.index_totals_html(t))
    if not page then return nil, err end
    -- The priority marker is optional while no row is the priority character:
    -- a template with no place to put the explanation and nothing to explain is
    -- not a broken template. With a priority row it is required, because the
    -- badge on that row would otherwise appear with nothing saying what it means.
    local note = M.priority_note_html(rows)
    local with_note, nerr = M.fill(page, "<!--__PRIORITY__-->", note)
    if with_note then
        page = with_note
    elseif note ~= "" then
        return nil, nerr
    end
    page, err = M.fill(page, "<!--__ROWS__-->", M.index_rows_html(rows))
    if not page then return nil, err end
    return page
end

-- --- characters.md ----------------------------------------------------------------------

local function md_cell(s) return (tostring(s):gsub("|", "\\|"):gsub("\n", " ")) end

function M.render_characters_md(rows, scheme)
    local t = M.totals(rows)
    local L = {}
    local function say(fmt, ...) L[#L + 1] = select("#", ...) > 0 and fmt:format(...) or fmt end
    say("# キャラクター一覧 — %s", scheme == "modern" and "Modern" or tostring(scheme))
    say("")
    say("`lua tools/lua/all.lua` が書き出す一覧です。手で編集しないでください。")
    say("ページ版は [index.html](index.html)（各キャラの接続マップとルート検索へのリンク付き）。")
    say("")
    say("- ワークリスト・DRC ペア・候補ルート・プランは**フレームデータからの予測**です。コンボではありません")
    say("- 確定コンボと試行は**実機のログだけ**から数えています")
    say("- Classic はまだありません（パイプラインの scheme は modern のみ）")
    say("")
    say("合計: %d キャラ · ワークリスト %s ペア · DRC %s ペア · 候補ルート %s（+DRC %s）· 確定コンボ %d · 試行 %s",
        t.characters, M.thousands(t.worklist_pairs), M.thousands(t.drc_pairs), M.thousands(t.routes),
        M.thousands(t.routes_drc), t.combos_confirmed, M.thousands(t.trials))
    say("")
    local plan_heads = {}
    for _, p in ipairs(M.PRESETS) do plan_heads[#plan_heads + 1] = p.name end
    say("| キャラ | ワークリスト | high / med / low | DRC | ルート | +DRC | %s | 確定 | 試行 | 1パス |",
        table.concat(plan_heads, " | "))
    say("|---|---:|---|---:|---:|---:|%s---:|---:|---|", ("---:|"):rep(#M.PRESETS))
    for _, r in ipairs(M.priority_first(rows)) do
        local c = r.worklist_confidence
        local plans = {}
        for _, p in ipairs(M.PRESETS) do
            local v = r.plans and r.plans[p.name]
            plans[#plans + 1] = v == nil and "-"
                or ("[%d](plans/%s-%s-%s.md)"):format(v, r.lc, r.control_scheme, p.name)
        end
        say("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |",
            (r.priority and "★ " or "")
                .. (r.page and ("[%s](%s)"):format(r.character, r.page) or r.character),
            dash(r.worklist_pairs),
            c and ("%d / %d / %d"):format(c.high, c.medium, c.low) or "-",
            dash(r.drc_pairs), dash(r.routes) .. (r.routes_complete == false and "\\*" or ""),
            dash(r.routes_drc),
            table.concat(plans, " | "),
            dash(r.combos_confirmed), dash(r.trials), M.pass_time(r.worklist_pairs))
    end
    say("")
    say("`*` ルート探索が beam の上限で打ち切られたキャラ。載っていないルートがあります（explore.lua と同じ設定）。")
    say("")
    local pri
    for _, r in ipairs(rows) do if r.priority then pri = r break end end
    if pri then
        local names = {}
        for _, p in ipairs(M.PRACTICE_PRESETS) do
            local v = pri.practice_plans and pri.practice_plans[p.name]
            names[#names + 1] = v == nil and ("`" .. p.name .. "`")
                or ("[%s](plans/%s-%s-%s.md) %d ペア")
                    :format(p.name, pri.lc, pri.control_scheme, p.name, v)
        end
        say("`★` 優先キャラ。%s だけ扱いが厚く、3 点だけ違います。", pri.character)
        say("")
        say("1. **深い探索** — %s、%s。ほかの 30 キャラは既定（beam 4,000・最大 3 手）のままです。",
            pri.deep and ("beam %s・最大 %s 手"):format(M.thousands(pri.deep.beam),
                                                        tostring(pri.deep.max_steps))
                or ("beam %s・最大 %s 手"):format(M.thousands(M.DEEP.beam),
                                                  tostring(M.DEEP.max_steps)),
            (pri.deep and pri.deep.complete) and "打ち切りなしで完走" or "打ち切りあり")
        say("2. **練習用プラン** — %s。", table.concat(names, " / "))
        say("3. **ルートファイル** — 練習プランの上位ルートを `reframework/data/ComboExplorer_data/route/` に%s。",
            pri.route_files and ("%d 本書き出し済み"):format(pri.route_files) or "書き出し済み")
        say("")
        say("それでも数字は全部予測です。%s の実機ログは %s 件。",
            pri.character, dash(pri.trials))
        say("")
    end
    local noted = {}
    for _, r in ipairs(rows) do if r.notes and #r.notes > 0 then noted[#noted + 1] = r end end
    say("## 注意が要るキャラ")
    say("")
    if #noted == 0 then
        say("ありません。")
    else
        for _, r in ipairs(noted) do
            say("- **%s**: %s", r.character, md_cell(table.concat(r.notes, " / ")))
        end
    end
    say("")
    say("オフライン候補レポート（explore.lua の全文）は `docs/ComboExplorer/<キャラ>-offline-report.md`。")
    say("ワークリストはフレームデータ由来で CC-BY-SA-4.0 です（docs/NOTICE.md）。")
    return table.concat(L, "\n") .. "\n"
end

-- --- the runbook's table -------------------------------------------------------------------

M.RUNBOOK_OPEN = "<!-- all.lua:pair-table -->"
M.RUNBOOK_CLOSE = "<!-- /all.lua:pair-table -->"

function M.runbook_table(rows)
    local L = { "| キャラ | ペア数 | 1パス | DRC ペア（まだ押せない） |", "|---|---:|---|---:|" }
    for _, r in ipairs(rows) do
        L[#L + 1] = ("| %s | %s | %s | %s |"):format(r.character, dash(r.worklist_pairs),
            M.pass_time(r.worklist_pairs), dash(r.drc_pairs))
    end
    return table.concat(L, "\n")
end

-- Replaces what sits between the two markers, keeping the markers. Refuses
-- when either is missing or they are out of order, rather than appending: a
-- table written to the end of a runbook is a table nobody finds.
function M.replace_between(text, open, close, body)
    local a, a_end = text:find(open, 1, true)
    if not a then return nil, "no " .. open .. " marker" end
    local b = text:find(close, a_end + 1, true)
    if not b then return nil, "no " .. close .. " marker after " .. open end
    local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
    body = body:gsub("\r?\n", nl)
    return text:sub(1, a_end) .. nl .. body .. nl .. text:sub(b)
end

return M
