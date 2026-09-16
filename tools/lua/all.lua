-- =========================================================
-- tools/lua/all.lua - every offline output, for every character, in one command.
--
--   lua tools/lua/all.lua [--only Ryu,Ken] [--jobs 4] [--scheme modern]
--                         [--no-index] [--index-only]
--                         [--deep Ryu | --no-deep]
--
-- Needs Lua 5.4, the catalogs and data/frame-data. Reads the committed trial
-- logs. No game, no network. Run from the repo root, like every other tool.
-- =========================================================
--
-- WHAT IT RUNS, PER CHARACTER
--
--   explore.lua --worklist --drive-rush   worklist/<char>-modern.json and -drc.json,
--                                         and the offline report, copied to
--                                         docs/ComboExplorer/<char>-offline-report.md
--   plan.lua, once per preset             batch.lua's PRESETS: max-damage,
--                                         no-gauge, starter-chu
--   report.lua --summary                  sweep-report-<char>-modern.html and
--                                         combos-<char>-modern.md
--
-- and then, over every character (not only the ones --only named, whose rows
-- replace their own in the last run's list):
--
--   docs/ComboExplorer/characters.json    the numbers
--   docs/ComboExplorer/index.html         the page linking every report
--   docs/ComboExplorer/characters.md      the same, for GitHub
--   docs/ComboExplorer/RUNBOOK.md         the pair-count table between its markers
--   docs/ComboExplorer/practice.md        the predicted-execution-ease ranking,
--   docs/ComboExplorer/practice.html      its page, and practice.json, the numbers
--                                         behind both (tools/lua/practice.lua; always
--                                         all 31 characters, since it is a ranking)
--
-- THE PRIORITY CHARACTER
--
-- --deep names the character somebody is actually practising with, and defaults
-- to Batch.DEFAULT_PRIORITY. That character, and only that character, gets:
--
--   a deeper search       Batch.DEEP - beam 60,000 and routes up to 4 moves,
--                         measured as the first setting where Ryu's search
--                         finishes instead of being cut by the beam. explore
--                         and every plan run at it, so the report, the route
--                         list and the plans are all talking about the same
--                         routes. The search's own truncation numbers are in
--                         the offline report and in each plan's `search` block.
--   the practice presets  Batch.PRACTICE_PRESETS, beside the standard three:
--                         easy-damage, hit-confirm, no-gauge-3
--   route files           the best routes of each practice preset, written as
--                         ce.route.v1 under .../route/ for the game to run
--
-- --no-deep turns it off, which is what a run that wants the plain 31 does.
-- Everybody else is untouched: same beam, same depth, same three presets, so
-- the batch is still three to five minutes.
--
-- easy-damage needs a number all.lua does not compute: the roster's cheap-route
-- cut, which is the 25th percentile of the execution_cost of every scored route
-- on every character. practice.lua writes it into practice.json at the end of
-- the run, so this reads the LAST run's figure and the plan's report says which
-- one it used. With no practice.json the preset is refused, not run without its
-- cut - "every no-gauge route" would produce a plausible plan of the wrong thing.
--
-- A character that fails does not stop the run. Its row says which step failed
-- and the step's log is under candidates/_batch/logs/. The exit code is 1 when
-- any character failed, so a script can tell.
--
-- WHY PROCESSES
--
-- The three tools are scripts: they read `arg`, and they os.exit on a refusal.
-- Running them in this interpreter would let one character's exit end the
-- batch. A process each keeps the rule "keep going when one fails" true without
-- rewriting three CLIs into libraries.
--
-- PARALLEL
--
-- --jobs N splits the characters into N lanes, each one `lua all.lua --lane`
-- process working through its characters in order. io.popen starts a process
-- and returns, so all lanes run at once and closing the handles waits for them.
-- Each character writes only its own files, so the lanes never write the same
-- one. The shared files are written after every lane has finished.
--
-- DETERMINISTIC
--
-- Every file this writes is a function of the committed inputs, except the
-- generated_at stamps the tools already put in their own outputs. The index,
-- characters.md and characters.json carry no timestamp, so rerunning with
-- nothing changed leaves them byte-identical. Timings are printed, not written.
-- practice.md/html/json do carry a generated_at, like the offline reports do.

local Cli = dofile("tools/lua/cli.lua")

local json       = dofile("tools/lua/json.lua")
local Characters = dofile("tools/lua/characters.lua")
local Batch      = dofile("tools/lua/batch.lua")

local TOOL = "all"
local WIN = package.config:sub(1, 1) == "\\"

local function default_jobs()
    local n = tonumber(os.getenv("NUMBER_OF_PROCESSORS") or "") or 2
    return math.max(1, math.min(4, n))
end

-- --index-only is a switch. Cli.parse wants a value after every --key, so the
-- bare spelling is given one here, the way planner.normalize_argv does for
-- plan.lua's switches.
local argv = {}
for i, a in ipairs(arg) do
    argv[#argv + 1] = a
    if a == "--index-only" and arg[i + 1] ~= "true" and arg[i + 1] ~= "false" then
        argv[#argv + 1] = "true"
    end
end

local opt = Cli.args(TOOL, argv, {
    scheme = "modern",
    jobs = default_jobs(),
    index = true,
    deep = Batch.DEFAULT_PRIORITY,
    lua = arg[-1] or "lua",
    batch_dir = "candidates/_batch",
    docs = "docs/ComboExplorer",
    data = "reframework/data/ComboExplorer_data",
})

if not Batch.SCHEMES[opt.scheme] then
    Cli.die(TOOL, ("--scheme %s: only modern is generated today. The pipeline excludes Classic "
        .. "rows from probing, so a classic run would be a modern run under another name.")
        :format(tostring(opt.scheme)))
end

local all_entries, aerr = Characters.all()
if not all_entries then Cli.die(TOOL, aerr) end

-- Which characters are priority, by catalog name. --no-deep leaves it empty.
-- An unknown name is refused here rather than silently running nobody deep -
-- the one thing worse than no deep run is a run that says it did one.
local PRIORITY = {}
if opt.deep ~= false and opt.deep ~= nil and opt.deep ~= "" then
    local picked, perr = Batch.select(tostring(opt.deep), all_entries, Characters.resolve)
    if not picked then Cli.die(TOOL, "--deep: " .. tostring(perr)) end
    for _, e in ipairs(picked) do PRIORITY[e.catalog] = true end
end

local LOG_DIR = opt.batch_dir .. "/logs"

-- --- small file helpers -------------------------------------------------------

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

local function now()
    -- os.clock is CPU time of this process, which is near zero while it waits
    -- on a child. Wall time is what a person waits for.
    return os.time()
end

-- --- one character -------------------------------------------------------------

local function run_step(entry, step, args)
    local log = ("%s/%s-%s.log"):format(LOG_DIR, entry.catalog:lower(), step)
    local line = Batch.command(opt.lua, args, log, WIN)
    local ok, how, code = os.execute(line)
    if ok then return true end
    -- The last lines of the log are the reason. The tools write their refusal
    -- to stderr, which is in the log.
    local text = read(log) or ""
    local tail = {}
    for l in text:gmatch("[^\r\n]+") do tail[#tail + 1] = l end
    local last = tail[#tail] or ("exit " .. tostring(code))
    return false, ("%s (exit %s; %s)"):format(last, tostring(code or how), log)
end

-- The roster's cheap-route cut, from the last run's practice.json. See the
-- header: it is a measurement of all 31 characters, so it cannot be computed
-- before the per-character runs that feed it.
local function cheap_cut()
    local doc = json.load_file(opt.docs .. "/practice.json")
    local v = doc and doc.settings and tonumber(doc.settings.cheap_threshold)
    return v
end
local CHEAP_CUT = cheap_cut()
local PRESET_VARS = { [Batch.VAR.CHEAP_CUT] = CHEAP_CUT }

local function run_character(entry)
    local lc = entry.catalog:lower()
    local scheme = opt.scheme
    local priority = PRIORITY[entry.catalog] == true
    local errors, secs = {}, {}
    local t0 = now()

    local function step(name, args)
        local s = now()
        local ok, err = run_step(entry, name, args)
        secs[name] = now() - s
        if not ok then errors[#errors + 1] = { step = name, message = err } end
        return ok
    end

    -- explore, and its report copied to where the committed copy lives
    local explore_args = { "tools/lua/explore.lua", "--character", entry.catalog,
                           "--scheme", scheme, "--worklist", "--drive-rush" }
    if priority then
        for _, a in ipairs(Batch.deep_args("explore")) do explore_args[#explore_args + 1] = a end
    end
    if step("explore", explore_args) then
        local src = ("candidates/%s/%s/report.md"):format(lc, scheme)
        local text = read(src)
        if text then
            write(("%s/%s-offline-report.md"):format(opt.docs, lc), text)
        else
            errors[#errors + 1] = { step = "explore", message = "no report at " .. src }
        end
    end

    for _, p in ipairs(Batch.presets_for(priority)) do
        local extra, missing = Batch.preset_args(p, PRESET_VARS)
        if not extra then
            errors[#errors + 1] = { step = "plan-" .. p.name, message =
                ("%s needs %s, and %s/practice.json does not carry it. Run all.lua once with "
                 .. "the index on to build it."):format(p.name, tostring(missing), opt.docs) }
        else
            local args = { "tools/lua/plan.lua", "--character", entry.catalog, "--scheme", scheme,
                           "--name", p.name }
            for _, a in ipairs(extra) do args[#args + 1] = a end
            if priority then
                for _, a in ipairs(Batch.deep_args("plan")) do args[#args + 1] = a end
                -- Route files for the practice presets only. The standard three
                -- are for choosing what to sweep; these are for running.
                if p.routes then
                    args[#args + 1] = "--routes"
                    args[#args + 1] = tostring(p.routes)
                end
            end
            step("plan-" .. p.name, args)
        end
    end

    local summary_path = ("%s/%s-report.json"):format(opt.batch_dir, lc)
    os.remove(summary_path)
    local report_args = { "tools/lua/report.lua", "--character", entry.catalog, "--scheme", scheme,
                          "--summary", summary_path }
    if priority then
        -- The page's route finder searches at the same settings, so the count
        -- on the page, the count in the offline report and the count the plans
        -- filtered are one number and not three.
        for _, a in ipairs(Batch.deep_args("report")) do report_args[#report_args + 1] = a end
    end
    step("report", report_args)

    -- the row, from what the steps left on disk
    local wl_dir = opt.data .. "/worklist"
    local explore = Batch.parse_explore_report(read(("%s/%s-offline-report.md"):format(opt.docs, lc)))
    local worklist = json.load_file(("%s/%s-%s.json"):format(wl_dir, lc, scheme))
    local drc = json.load_file(("%s/%s-%s-drc.json"):format(wl_dir, lc, scheme))
    local plans = {}
    for _, p in ipairs(Batch.presets_for(priority)) do
        plans[p.name] = json.load_file(("%s/%s-%s-plan-%s.json"):format(wl_dir, lc, scheme, p.name))
    end
    local summary = json.load_file(summary_path)
    -- Counted off the disk, not from what the presets asked for: a route the
    -- writer refused (a Drive Rush Cancel step it cannot name) leaves no file,
    -- and the index should say how many the game can actually run.
    local route_files = 0
    if priority then
        local prefix = ("%s-%s-"):format(lc, scheme)
        for _, p in ipairs(Batch.PRACTICE_PRESETS) do
            for _, fname in ipairs(Cli.list_dir(opt.data .. "/route")) do
                if fname:match("%.json$") and fname:sub(1, #prefix + #p.name + 1)
                    == (prefix .. p.name .. "-") then
                    route_files = route_files + 1
                end
            end
        end
    end
    local row = Batch.row(entry, scheme, explore, worklist, drc, plans, summary, errors,
        { priority = priority, route_files = priority and route_files or nil })

    local result = { row = row, seconds = now() - t0, step_seconds = secs }
    json.save_file(("%s/%s.json"):format(opt.batch_dir, lc), result, { indent = "  " })
    return result
end

-- --- a lane: several characters, one after another --------------------------------

if opt.lane then
    Cli.mkdir(LOG_DIR)
    -- A lane names its characters. An empty one is a bug in the caller, and
    -- select() reads "no names" as "everyone", which here would run 31.
    if type(opt.lane) ~= "string" or opt.lane == "" or opt.lane == true then
        Cli.die(TOOL, "--lane needs character names")
    end
    local entries = Batch.select(opt.lane, all_entries, Characters.resolve)
    if not entries then Cli.die(TOOL, "bad --lane " .. tostring(opt.lane)) end
    for _, e in ipairs(entries) do
        print(("[%s] %s"):format(os.date("%H:%M:%S"), e.catalog))
        io.stdout:flush()
        local r = run_character(e)
        print(("  %ds%s"):format(r.seconds, r.row.errors and "  FAILED" or ""))
        io.stdout:flush()
    end
    os.exit(0)
end

-- --- the run ------------------------------------------------------------------------

local targets, serr = Batch.select(opt.only, all_entries, Characters.resolve)
if not targets then Cli.die(TOOL, serr) end
-- --index-only rebuilds the index, characters.md and the runbook table from the
-- last run's characters.json without running anything: for a change to the
-- page or the notes, which does not need seven minutes of pipeline.
if opt.index_only then targets = {} end

Cli.mkdir(LOG_DIR)
Cli.mkdir(opt.docs)
-- A result file left from an earlier run would be read as this run's if the
-- lane for that character died before writing one.
for _, e in ipairs(targets) do os.remove(("%s/%s.json"):format(opt.batch_dir, e.catalog:lower())) end

local started = now()
local jobs = math.max(1, math.floor(tonumber(opt.jobs) or 1))
print(("all: %d character(s), %s, %d job(s). Step logs in %s/"):format(
    #targets, opt.scheme, math.min(jobs, #targets), LOG_DIR))
do
    local names = {}
    for _, e in ipairs(all_entries) do
        if PRIORITY[e.catalog] then names[#names + 1] = e.catalog end
    end
    if #names > 0 then
        print(("  priority: %s - beam %d, up to %d moves, %d standard + %d practice preset(s), "
            .. "route files for the practice ones"):format(
            table.concat(names, ", "), Batch.DEEP.beam, Batch.DEEP.max_steps,
            #Batch.PRESETS, #Batch.PRACTICE_PRESETS))
        print(("  cheap-route cut for easy-damage: %s"):format(
            CHEAP_CUT and ("execution_cost <= %.2f (from %s/practice.json)")
                :format(CHEAP_CUT, opt.docs)
                or "MISSING - no practice.json, so easy-damage will be refused"))
    else
        print("  priority: none (--no-deep) - every character on explore.lua's own settings")
    end
end

if #targets == 0 then
    -- --index-only: nothing to run.
elseif jobs <= 1 or #targets == 1 then
    for i, e in ipairs(targets) do
        io.write(("[%2d/%d] %-10s "):format(i, #targets, e.catalog))
        io.stdout:flush()
        local r = run_character(e)
        print(("%4ds%s"):format(r.seconds, r.row.errors and "  FAILED" or ""))
    end
else
    local handles = {}
    for i, lane in ipairs(Batch.lanes(targets, jobs)) do
        local names = {}
        for _, e in ipairs(lane) do names[#names + 1] = e.catalog end
        local log = ("%s/lane-%d.log"):format(LOG_DIR, i)
        local deep_names = {}
        for _, e in ipairs(lane) do
            if PRIORITY[e.catalog] then deep_names[#deep_names + 1] = e.catalog end
        end
        local args = { "tools/lua/all.lua", "--lane", table.concat(names, ","),
                       "--scheme", opt.scheme, "--lua", opt.lua,
                       "--batch-dir", opt.batch_dir, "--docs", opt.docs, "--data", opt.data }
        -- Only the priority characters IN THIS LANE, so a lane without one does
        -- not have to resolve a name it will never run.
        if #deep_names > 0 then
            args[#args + 1] = "--deep"
            args[#args + 1] = table.concat(deep_names, ",")
        else
            args[#args + 1] = "--no-deep"
        end
        print(("  lane %d: %s"):format(i, table.concat(names, ", ")))
        handles[i] = io.popen(Batch.command(opt.lua, args, log, WIN), "r")
    end
    io.stdout:flush()
    for i, h in ipairs(handles) do
        h:read("a")
        h:close()
    end
end

-- --- gathering ----------------------------------------------------------------------

local new_rows, timings = {}, {}
for _, e in ipairs(targets) do
    local lc = e.catalog:lower()
    local r = json.load_file(("%s/%s.json"):format(opt.batch_dir, lc))
    if r and r.row then
        new_rows[#new_rows + 1] = r.row
        timings[e.catalog] = r.seconds
    else
        -- The lane died without writing this character's result.
        local row = Batch.row(e, opt.scheme, nil, nil, nil, {}, nil,
            { { step = "batch", message = "no result written - see " .. LOG_DIR .. "/lane-*.log" } })
        new_rows[#new_rows + 1] = row
    end
end

local index_path = opt.docs .. "/characters.json"
local previous = json.load_file(index_path)
local rows = Batch.merge_rows(previous and previous.characters or {}, new_rows)
-- Notes are recomputed for every row, kept ones included, so a change to what
-- batch.lua notes reaches the whole index and not only the characters rerun.
for _, r in ipairs(rows) do r.notes = Batch.notes(r) end

-- Only this run's rows are printed; the index holds every character.
local printed = Batch.merge_rows({}, new_rows)
print("")
for _, l in ipairs(Batch.summary_lines(printed, timings)) do print(l) end
print("")
print("rows = catalog rows, cands = candidate edges, routes = route finder routes (+drc = through a")
print("Drive Rush Cancel), pairs / drc = worklist pairs, maxd / nog / chu = plan pairs per preset")

local failed = 0
for _, r in ipairs(printed) do
    if r.errors then
        failed = failed + 1
        for _, e in ipairs(r.errors) do print(("  %s %s: %s"):format(r.character, e.step, e.message)) end
    end
end

if opt.index ~= false then
    json.save_file(index_path, { schema = "ce.character_index.v1", control_scheme = opt.scheme,
                                 presets = Batch.PRESETS, characters = rows }, { indent = "  " })

    local template = read("tools/lua/index-template.html")
    if not template then Cli.die(TOOL, "no index template at tools/lua/index-template.html") end
    local page, perr = Batch.render_index(template, rows)
    if not page then Cli.die(TOOL, perr) end
    write(opt.docs .. "/index.html", page)
    write(opt.docs .. "/characters.md", Batch.render_characters_md(rows, opt.scheme))

    local rb_path = opt.docs .. "/RUNBOOK.md"
    local rb = read(rb_path)
    local updated, rerr = rb and Batch.replace_between(rb, Batch.RUNBOOK_OPEN, Batch.RUNBOOK_CLOSE,
                                                       Batch.runbook_table(rows))
    if updated then
        if updated ~= rb then write(rb_path, updated) end
    else
        io.stderr:write(("all: RUNBOOK.md table not updated: %s\n"):format(tostring(rerr or "no runbook")))
    end

    local t = Batch.totals(rows)
    print("")
    print(("written: %s/index.html, characters.md, characters.json (%d characters)"):format(opt.docs, #rows))
    print(("report pages: %s across %d characters"):format(Batch.bytes(t.page_bytes), #rows))

    -- practice.md / practice.html: the predicted-execution-ease ranking. It is
    -- a cross-character document, so it always covers all 31 whatever --only
    -- said - a ranking over four characters would be a different ranking.
    --
    -- Four of its five components need PER-ROUTE scores, and characters.json
    -- carries none, so --index-only cannot recompute them: it re-renders from
    -- practice.json instead, which is what --from-cache does (and which falls
    -- back to a full minute-long run when there is no practice.json yet).
    local pargs = { "tools/lua/practice.lua", "--scheme", opt.scheme,
                    "--docs", opt.docs, "--data", opt.data }
    if opt.index_only then pargs[#pargs + 1] = "--from-cache" end
    local plog = ("%s/practice.log"):format(LOG_DIR)
    local pok = os.execute(Batch.command(opt.lua, pargs, plog, WIN))
    if pok then
        print(("written: %s/practice.md, practice.html, practice.json%s"):format(
            opt.docs, opt.index_only and " (re-rendered from practice.json)" or ""))
    else
        failed = failed + 1
        io.stderr:write(("all: practice.lua failed - see %s\n"):format(plog))
    end
end

print(("elapsed: %ds"):format(now() - started))
os.exit(failed == 0 and 0 or 1)
