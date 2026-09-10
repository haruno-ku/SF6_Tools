-- =========================================================
-- tools/lua/audit.lua - runs Catalog.build over every shipped command_display
-- file and prints one table.
--
--   lua tools/lua/audit.lua [--character all|<Name>] [--out <dir>]
--
-- Needs Lua 5.4 and nothing else. No frame data, no game, no network.
-- =========================================================
--
-- THE QUESTION THIS ANSWERS
--
-- The whole pipeline was built and checked against one character. Everything
-- downstream keys off the classifier in core/Catalog.lua, so if that classifier
-- only understands the notation Zangief happens to use, every other character
-- produces a catalog that looks healthy and is missing moves.
--
-- Running the candidate generator over 31 characters would NOT find that. It
-- would produce thousands of plausible-looking candidates built on the gap, and
-- the gap would be invisible under the volume. Counting first is the cheap
-- version, and it is why this runs before #20.
--
-- WHAT IT DELIBERATELY DOES NOT DO
--
-- It does not classify anything itself, and it does not decide that a notation
-- the classifier missed "is really a special". It reports what Catalog.build
-- did with each row and lets the numbers be uneven. A tool that quietly
-- repaired the classifier's misses while measuring them would report a clean
-- sheet for a pipeline that is not clean.

package.path = table.concat({ "./?.lua", "./?/init.lua", package.path }, ";")

-- Same require shim as explore.lua: REFramework resolves require("func/X/Y")
-- relative to reframework/autorun, so the shipped modules keep the paths they
-- will actually run under.
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

local json    = dofile("tools/lua/json.lua")
local Catalog = require("func/ComboExplorer/core/Catalog")

-- --- arguments ---------------------------------------------------------------

local opt = {
    character = "all",
    dir = "reframework/data/TrainingComboTrials_data/command_display",
    out = "docs/ComboExplorer",
}

local i = 1
while i <= #arg do
    local key = arg[i]:match("^%-%-([%w%-]+)$")
    local v = arg[i + 1]
    if not key then
        io.stderr:write(("unrecognised argument %q\n"):format(arg[i]))
        os.exit(2)
    end
    if v == nil then
        io.stderr:write(("--%s needs a value\n"):format(key))
        os.exit(2)
    end
    opt[(key:gsub("%-", "_"))] = v
    i = i + 2
end

local function die(msg)
    io.stderr:write("audit: " .. msg .. "\n")
    os.exit(1)
end

-- --- the character list ------------------------------------------------------

local function list_catalogs(dir)
    local names = {}
    local windows = package.config:sub(1, 1) == "\\"
    local cmd = windows
        and ('cmd /c dir /b "%s\\*.json" 2>nul'):format(dir:gsub("/", "\\"))
        or ('ls -1 "%s"/*.json 2>/dev/null'):format(dir)
    local p = io.popen(cmd)
    if not p then return names end
    for line in p:lines() do
        local base = line:match("([^/\\]+)%.json$")
        if base then names[#names + 1] = base end
    end
    p:close()
    table.sort(names)
    return names
end

local characters
if opt.character == "all" then
    characters = list_catalogs(opt.dir)
    if #characters == 0 then die("no command_display files under " .. opt.dir) end
else
    characters = { opt.character }
end

-- --- measurement -------------------------------------------------------------

-- One row per character. Everything here is read back off what Catalog.build
-- produced; nothing is recomputed by a second implementation that could
-- disagree with the one that ships.
local function measure(name)
    local path = ("%s/%s.json"):format(opt.dir, name)
    local raw, jerr = json.load_file(path)
    if not raw then return nil, ("could not read %s: %s"):format(path, tostring(jerr)) end

    local cat, problems = Catalog.build(raw)
    if not cat then
        local why = problems and problems[1] and problems[1].reason or "unknown"
        return nil, ("Catalog.build refused %s: %s"):format(path, why)
    end

    local m = {
        character = name,
        source_character = cat.character,
        generated_at = cat.generated_at,
        ac_sha256 = cat.ac_sha256,
        counts = cat.counts,
        problems = #problems,
        problems_by_reason = {},
        parse_error = 0,
        unplaceable = 0,          -- category could not be decided
        unplaceable_lost = 0,     -- ... and that is the only reason it was dropped
        unplaceable_rows = {},
        by_category = {},
    }

    for _, pr in ipairs(problems) do
        local r = tostring(pr.reason)
        m.problems_by_reason[r] = (m.problems_by_reason[r] or 0) + 1
    end

    for _, row in ipairs(cat.rows) do
        m.by_category[row.category] = (m.by_category[row.category] or 0) + 1
        if row.parse_error then m.parse_error = m.parse_error + 1 end

        if row.category == "unknown" then
            m.unplaceable = m.unplaceable + 1

            -- Dropped for no reason other than that the classifier had no
            -- vocabulary for the notation.
            --
            -- This used to look for exclusion == "system", because that is what
            -- an unrecognised category turned into. Catalog.build now gives it
            -- its own name, and this check followed the rename rather than
            -- being left to read zero - a metric that goes quiet because the
            -- thing it counted was renamed is worse than no metric, since it
            -- reports the problem as solved.
            local lost = (row.exclusion == "unclassified")
            if lost then
                m.unplaceable_lost = m.unplaceable_lost + 1
                m.unplaceable_rows[#m.unplaceable_rows + 1] = {
                    action_id = row.action_id,
                    classic = row.classic,
                    input_method = row.input_method,
                    ownership = row.ownership,
                }
            end
        end
    end

    table.sort(m.unplaceable_rows, function(a, b) return a.action_id < b.action_id end)
    return m
end

local rows, failures = {}, {}
for _, name in ipairs(characters) do
    local m, err = measure(name)
    if m then rows[#rows + 1] = m else failures[#failures + 1] = err end
end
if #rows == 0 then die("nothing could be measured\n  " .. table.concat(failures, "\n  ")) end

-- --- cross-character rollups -------------------------------------------------

-- A notation the classifier could not place, and every character it appears
-- for. This is the actionable list: it is what #21 has to teach the classifier,
-- ordered by how many characters it costs.
local unplaced = {}
for _, m in ipairs(rows) do
    local seen = {}
    for _, r in ipairs(m.unplaceable_rows) do
        local key = tostring(r.classic)
        local u = unplaced[key]
        if not u then
            u = { notation = key, characters = {}, rows = 0 }
            unplaced[key] = u
        end
        u.rows = u.rows + 1
        if not seen[key] then
            seen[key] = true
            u.characters[#u.characters + 1] = m.character
        end
    end
end

local unplaced_sorted = {}
for _, u in pairs(unplaced) do unplaced_sorted[#unplaced_sorted + 1] = u end
table.sort(unplaced_sorted, function(a, b)
    if #a.characters ~= #b.characters then return #a.characters > #b.characters end
    if a.rows ~= b.rows then return a.rows > b.rows end
    return a.notation < b.notation
end)

local exclusion_keys, problem_keys = {}, {}
do
    local seen_e, seen_p = {}, {}
    for _, m in ipairs(rows) do
        for k in pairs(m.counts.by_exclusion) do
            if not seen_e[k] then seen_e[k] = true; exclusion_keys[#exclusion_keys + 1] = k end
        end
        for k in pairs(m.problems_by_reason) do
            if not seen_p[k] then seen_p[k] = true; problem_keys[#problem_keys + 1] = k end
        end
    end
    table.sort(exclusion_keys)
    table.sort(problem_keys)
end

-- --- the report --------------------------------------------------------------

local out = {}
local function say(fmt, ...)
    local line = select("#", ...) > 0 and fmt:format(...) or fmt
    out[#out + 1] = line
    print(line)
end

say("# Catalog audit - %d character(s)", #rows)
say("")
say("Catalog.build over the shipped command_display files. No frame data, no")
say("game: this measures the classifier, not the moves.")
say("")

if #failures > 0 then
    say("## Files that could not be measured")
    say("")
    for _, f in ipairs(failures) do say("- %s", f) end
    say("")
end

say("## Per character")
say("")
say("```")
say("%-10s %5s %5s %5s %5s %5s %6s %6s %5s %5s",
    "char", "entr", "rows", "stand", "excl", "unrch", "unplc", "LOST", "perr", "prob")
for _, m in ipairs(rows) do
    local c = m.counts
    say("%-10s %5d %5d %5d %5d %5d %6d %6d %5d %5d",
        m.character, c.entries, c.rows, c.standalone, c.excluded, c.unreachable,
        m.unplaceable, m.unplaceable_lost, m.parse_error, m.problems)
end
say("```")
say("")
say("- `unrch` no Modern command form at all, so the row never exists")
say("- `unplc` rows the classifier could not place a category on")
say("- `LOST`  of those, the ones excluded as `unclassified` - dropped for no reason")
say("          other than that the classifier had no vocabulary for the notation")
say("- `perr`  rows whose notation InputMask could not parse")
say("- `prob`  entries Catalog.build reported as problems")
say("")

say("## Excluded, by reason")
say("")
say("```")
local hdr = { ("%-10s"):format("char") }
for _, k in ipairs(exclusion_keys) do hdr[#hdr + 1] = ("%13s"):format(k) end
say("%s", table.concat(hdr))
for _, m in ipairs(rows) do
    local line = { ("%-10s"):format(m.character) }
    for _, k in ipairs(exclusion_keys) do
        line[#line + 1] = ("%13d"):format(m.counts.by_exclusion[k] or 0)
    end
    say("%s", table.concat(line))
end
say("```")
say("")

say("## Notations the classifier could not place")
say("")
if #unplaced_sorted == 0 then
    say("None. Every row got a category.")
else
    say("Sorted by how many characters each one costs. A row here was excluded")
    say("as `unclassified`: the category came back unknown, and nothing in the")
    say("data says the move is unusable - only that this classifier has no word")
    say("for how it is written.")
    say("")
    say("```")
    say("%-5s %-5s %-24s %s", "chars", "rows", "notation", "characters")
    for _, u in ipairs(unplaced_sorted) do
        local who = table.concat(u.characters, ",")
        if #who > 70 then who = who:sub(1, 67) .. "..." end
        say("%-5d %-5d %-24s %s", #u.characters, u.rows, u.notation, who)
    end
    say("```")
end
say("")

if #problem_keys > 0 then
    say("## Problems, by reason")
    say("")
    -- Numbered columns with a legend below. The reasons are whole sentences and
    -- truncating them to a column width turns two different problems into the
    -- same unreadable stub.
    for n, k in ipairs(problem_keys) do say("%d. %s", n, k) end
    say("")
    say("```")
    local h = { ("%-10s"):format("char") }
    for n = 1, #problem_keys do h[#h + 1] = ("%6s"):format("#" .. n) end
    say("%s", table.concat(h))
    for _, m in ipairs(rows) do
        local line = { ("%-10s"):format(m.character) }
        for _, k in ipairs(problem_keys) do
            line[#line + 1] = ("%6d"):format(m.problems_by_reason[k] or 0)
        end
        say("%s", table.concat(line))
    end
    say("```")
    say("")
end

-- --- the verdict -------------------------------------------------------------
--
-- Stated as a comparison against the one character the pipeline was built on,
-- because that is the actual question: is this general, or is it Zangief's.

local baseline
for _, m in ipairs(rows) do if m.character == "Zangief" then baseline = m end end

say("## Verdict")
say("")
local affected, worst_n, worst = 0, -1, nil
local total_lost = 0
for _, m in ipairs(rows) do
    total_lost = total_lost + m.unplaceable_lost
    if m.unplaceable_lost > 0 then affected = affected + 1 end
    if m.unplaceable_lost > worst_n then worst_n, worst = m.unplaceable_lost, m end
end

say("%d row(s) across %d of %d character(s) are excluded as `unclassified`:",
    total_lost, affected, #rows)
say("dropped for no reason other than that the classifier could not place them.")
say("")
if baseline then
    say("Zangief, the character the pipeline was built against, loses %d.",
        baseline.unplaceable_lost)
    say("The worst case is %s at %d.", worst.character, worst.unplaceable_lost)
    say("")
    if worst_n > baseline.unplaceable_lost * 2 then
        say("That is not a uniform gap. The classifier does not describe every")
        say("character equally well, and the characters it describes worst lose")
        say("moves with no record that a move was lost. Extending it is #21;")
        say("candidate generation for the other 30 (#20) is built on top of it,")
        say("and running #20 first would bury this under volume.")
    else
        say("The gap is roughly even across characters, so what is missing is not")
        say("specific to how one character's notation is written.")
    end
else
    say("Zangief was not in this run, so there is no baseline to compare against.")
end
say("")
say("Nothing here says a listed notation IS a special, a normal or anything")
say("else. It says the classifier has no opinion on it and the exclusion chain")
say("defaults to dropping it.")

-- --- written artifacts -------------------------------------------------------

local function mkdir(path)
    local cmd = (package.config:sub(1, 1) == "\\")
        and ('cmd /c if not exist "%s" mkdir "%s" >nul 2>&1')
            :format(path:gsub("/", "\\"), path:gsub("/", "\\"))
        or ('mkdir -p "%s"'):format(path)
    os.execute(cmd)
end
mkdir(opt.out)

-- A one-character run writes to its own name. Sharing the filename would let
-- `--character Guile` silently replace the 31-character report with a report
-- about Guile, under a name that still reads as the whole audit.
local stem = (opt.character == "all") and "catalog-audit"
    or ("catalog-audit-" .. opt.character:gsub("[^%w_]", ""))

local md = opt.out .. "/" .. stem .. ".md"
local f = io.open(md, "wb")
if f then
    f:write(table.concat(out, "\n"))
    f:write("\n")
    f:close()
end

-- The JSON carries the per-row detail the table cannot: which action ids were
-- dropped, for whom. #21 needs the ids, not the totals.
local doc = {
    schema = "ce.catalog_audit.v1",
    generated_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    source_dir = opt.dir,
    characters = rows,
    unplaced_notations = unplaced_sorted,
    failures = failures,
}
local jpath = opt.out .. "/" .. stem .. ".json"
local n = json.save_file(jpath, doc, { indent = "  " })

print("")
print(("written: %s"):format(md))
if n then print(("written: %s  (%d bytes)"):format(jpath, n)) end
