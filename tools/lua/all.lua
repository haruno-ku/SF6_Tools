-- =========================================================
-- tools/lua/all.lua - every offline output, for every character, in one command.
--
--   lua tools/lua/all.lua [--only Ryu,Ken] [--jobs 4] [--scheme modern]
--                         [--no-index] [--index-only]
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

local function run_character(entry)
    local lc = entry.catalog:lower()
    local scheme = opt.scheme
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
    if step("explore", { "tools/lua/explore.lua", "--character", entry.catalog,
                         "--scheme", scheme, "--worklist", "--drive-rush" }) then
        local src = ("candidates/%s/%s/report.md"):format(lc, scheme)
        local text = read(src)
        if text then
            write(("%s/%s-offline-report.md"):format(opt.docs, lc), text)
        else
            errors[#errors + 1] = { step = "explore", message = "no report at " .. src }
        end
    end

    for _, p in ipairs(Batch.PRESETS) do
        local args = { "tools/lua/plan.lua", "--character", entry.catalog, "--scheme", scheme,
                       "--name", p.name }
        for _, a in ipairs(p.args) do args[#args + 1] = a end
        step("plan-" .. p.name, args)
    end

    local summary_path = ("%s/%s-report.json"):format(opt.batch_dir, lc)
    os.remove(summary_path)
    step("report", { "tools/lua/report.lua", "--character", entry.catalog, "--scheme", scheme,
                     "--summary", summary_path })

    -- the row, from what the steps left on disk
    local wl_dir = opt.data .. "/worklist"
    local explore = Batch.parse_explore_report(read(("%s/%s-offline-report.md"):format(opt.docs, lc)))
    local worklist = json.load_file(("%s/%s-%s.json"):format(wl_dir, lc, scheme))
    local drc = json.load_file(("%s/%s-%s-drc.json"):format(wl_dir, lc, scheme))
    local plans = {}
    for _, p in ipairs(Batch.PRESETS) do
        plans[p.name] = json.load_file(("%s/%s-%s-plan-%s.json"):format(wl_dir, lc, scheme, p.name))
    end
    local summary = json.load_file(summary_path)
    local row = Batch.row(entry, scheme, explore, worklist, drc, plans, summary, errors)

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
        local args = { "tools/lua/all.lua", "--lane", table.concat(names, ","),
                       "--scheme", opt.scheme, "--lua", opt.lua,
                       "--batch-dir", opt.batch_dir, "--docs", opt.docs, "--data", opt.data }
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
end

print(("elapsed: %ds"):format(now() - started))
os.exit(failed == 0 and 0 or 1)
