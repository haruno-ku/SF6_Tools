-- =========================================================
-- tools/lua/labknown.lua - the lab database's evaluation, run off the committed
-- logs, without a database. Dev-machine only, like the rest of tools/.
-- =========================================================
--
-- WHY THIS EXISTS
--
-- The page and plan.lua used to read a pair's answer straight off
-- ConfirmedEdge: any cohort that answered "no" made the pair `rejected`, and a
-- route through it was demoted and flagged. tools/lua/labeval.lua (policy
-- ce-eval-v1, applied in the lab database) says most of those negatives never
-- asked the question - the pair was pressed at gap 4, inside A's animation
-- (#46); at a link gap on a cancel-only pair, after A had recovered; with the
-- button a motion's worth of ticks late; or with an input today's compiler
-- would not press at all (#49). On the committed logs that is 352 of 856 runs.
--
-- The database now judges them with that policy. This module lets the page and
-- the plan judge them with the SAME policy, from the same files, so the two
-- cannot disagree about what "rejected" means: it builds the rows
-- tools/lua/labrows.lua builds, hands them to tools/lua/labeval.lua, and gives
-- the caller the evaluations. It adds no rule of its own.
--
-- WHAT IS NOT HERE
--
-- Hashing. tools/db/lab-import.mjs keys a run by the SHA-256 of its record's
-- canonical JSON, so two identical lines in two files are one run with two
-- source locations (and the union of their flags). There is one SHA-256 in this
-- project and it is in Node. What identity needs here is only that identical
-- records collide and different ones do not, so the canonical JSON ITSELF is
-- the key - tools/lua/json.lua sorts object keys, which is what makes it
-- canonical. The keys never leave this process; nothing is stored under them.
--
-- WHAT A CALLER HAS TO PROVIDE
--
-- The pair lookup (mechanism, notations, whether the generator still produces
-- the pair) and the route definitions, exactly as tools/lua/labrows-cli.lua
-- gives them: this module loads no catalog and runs no generator, so every rule
-- below is testable on a table.

local json            = dofile("tools/lua/json.lua")
local LabRows         = dofile("tools/lua/labrows.lua")
local LabEval         = dofile("tools/lua/labeval.lua")
local ResultCollector = require("func/ComboExplorer/core/ResultCollector")

local M = { name = "tools.labknown" }

M.POLICY = LabEval.DEFAULT_POLICY

-- --- reading a log the way the importer reads it ---------------------------------

-- One trial file, as tools/lua/labrows-cli.lua reads it: every line numbered
-- from 1, the unterminated last line left out (ResultCollector's rule - a line
-- with no terminator is the tail of a trial whose result was lost), blanks
-- skipped, and a line that will not decode counted rather than dropped.
--
-- Returns { { line_no, record }, ... }, bad_lines.
function M.scan_trials(text)
    local out, bad = {}, 0
    local lines, info = ResultCollector.scan(text or "")
    if not lines then return out, 0 end
    for i, raw in ipairs(lines) do
        if i == #lines and info.unterminated then
            bad = bad + 1
        elseif not raw:match("^%s*$") then
            local ok, rec = pcall(json.decode, raw)
            if ok and type(rec) == "table" then
                out[#out + 1] = { line_no = i, record = rec }
            else
                bad = bad + 1
            end
        end
    end
    return out, bad
end

-- data_dir : reframework/data/ComboExplorer_data
-- Returns { { path, base, records = { { line_no, record } }, bad_lines } , ... }
-- for every <char>-*.jsonl, in listing order. read_file defaults to io.open.
function M.load_trials(data_dir, char_lc, list_dir, read_file)
    read_file = read_file or function(path)
        local f = io.open(path, "rb")
        if not f then return nil end
        local text = f:read("a")
        f:close()
        return text
    end
    local out = {}
    local prefix = tostring(char_lc) .. "-"
    for _, name in ipairs(list_dir(data_dir .. "/trials") or {}) do
        if name:sub(1, #prefix) == prefix and name:match("%.jsonl$") then
            local path = ("%s/trials/%s"):format(data_dir, name)
            local text = read_file(path)
            if text then
                local records, bad = M.scan_trials(text)
                out[#out + 1] = { path = path, base = name, records = records, bad_lines = bad }
            end
        end
    end
    return out
end

-- --- the rows ---------------------------------------------------------------------

-- The identity two lines have to share to be one observation. See the header:
-- the canonical JSON, not a hash of it.
function M.event_key(rec)
    return "json:" .. json.encode(rec)
end

-- files  : { { path, base, records = { { line_no, record } } }, ... }
--          `path` is what a row records as its source; `base` selects
--          LabRows.FILES (the file-level rules: the fixed-gap sweep, and which
--          file supersedes which).
-- lookup : labrows' lookup table - { pair(character, scheme, key), notation(...),
--          route(id) }. Any of them may be absent.
-- keep   : optional predicate(record) -> boolean. plan.lua and report.lua drop
--          records from another control scheme before folding; a record that
--          does not say which scheme it is is kept, because absence is not a
--          different scheme.
--
-- Returns rows (one per DISTINCT record, each with event_key and sources, the
-- shape tools/lua/labeval.lua reads), problems, counts.
function M.rows(files, lookup, keep)
    local by_base = {}
    for _, f in ipairs(files or {}) do by_base[f.base or LabRows.basename(f.path)] = f end

    local rows, order, problems = {}, {}, {}
    local counts = { lines = 0, rows = 0, duplicates = 0, problems = 0, skipped = 0 }

    for _, file in ipairs(files or {}) do
        local base = file.base or LabRows.basename(file.path)
        local rule = LabRows.FILES[base] or {}

        local successor
        if rule.superseded_by and by_base[rule.superseded_by] then
            successor = LabRows.index_reruns(by_base[rule.superseded_by].records)
        end
        local predecessor
        for pbase, prule in pairs(LabRows.FILES) do
            if prule.superseded_by == base and by_base[pbase] then
                predecessor = { source_file = by_base[pbase].path,
                                index = LabRows.index_reruns(by_base[pbase].records) }
            end
        end

        for _, r in ipairs(file.records or {}) do
            counts.lines = counts.lines + 1
            if keep and not keep(r.record) then
                counts.skipped = counts.skipped + 1
            else
                local row, why = LabRows.row(r.record, {
                    source_file = file.path, line_no = r.line_no, lookup = lookup,
                    successor = successor, predecessor = predecessor,
                })
                if not row then
                    counts.problems = counts.problems + 1
                    local parts = {}
                    for i, p in ipairs(why or {}) do
                        parts[i] = ("%s: %s"):format(tostring(p.field), tostring(p.problem))
                    end
                    problems[#problems + 1] = ("%s line %d: %s")
                        :format(file.path, r.line_no, table.concat(parts, "; "))
                else
                    local key = M.event_key(r.record)
                    local seen = rows[key]
                    local source = { source_file = file.path, line_no = r.line_no,
                                     quality_flags = row.quality_flags }
                    if seen then
                        -- The same observation committed twice. One run, both
                        -- locations, and the union of their flags - what
                        -- lab.run_quality reads (labeval.flags_of does the union).
                        counts.duplicates = counts.duplicates + 1
                        seen.sources[#seen.sources + 1] = source
                    else
                        row.event_key = key
                        row.sources = { source }
                        rows[key] = row
                        order[#order + 1] = row
                    end
                end
            end
        end
    end

    counts.rows = #order
    return order, problems, counts
end

-- --- the evaluations -----------------------------------------------------------------

-- rows : from M.rows. opts.policy : a policy key (default ce-eval-v1).
-- Returns evaluations, problems, policy - tools/lua/labeval.lua's own output.
function M.evaluate(rows, opts)
    return LabEval.evaluate(rows, opts or { policy = M.POLICY })
end

-- files + lookup straight through to the evaluations, for a caller that has
-- nothing to do with the rows in between.
function M.from_files(files, lookup, opts)
    opts = opts or {}
    local rows, row_problems, counts = M.rows(files, lookup, opts.keep)
    local evaluations, problems, policy = M.evaluate(rows, { policy = opts.policy or M.POLICY })
    local all = {}
    for _, p in ipairs(row_problems) do all[#all + 1] = p end
    for _, p in ipairs(problems or {}) do all[#all + 1] = p end
    return evaluations, all, policy, counts
end

-- --- the pair lookup, from a loaded pipeline context ----------------------------------

-- The lookup tools/lua/labrows-cli.lua builds, over ONE character and scheme
-- that the caller has already loaded. A record from another character or scheme
-- gets no pair information rather than this one's - a wrong mechanism would set
-- a flag about the wrong move.
--
-- pair_index : LabRows.pair_index(ctx.plain_edges, gen.excluded, Pipeline.edge_pair_key)
-- notation   : { ["<id>:<method>"] = notation }
-- routes     : { [route_id] = ce.route.v1 }
function M.lookup(character, scheme, pair_index, notation, routes)
    local function mine(c, s)
        return (c == nil or c == character) and (s == nil or s == scheme)
    end
    return {
        pair = function(c, s, key)
            if not mine(c, s) or not pair_index then return nil end
            return pair_index(key)
        end,
        notation = function(c, s, id, method)
            if not mine(c, s) or not notation then return nil end
            return notation[("%s:%s"):format(id, tostring(method))]
        end,
        route = function(id) return routes and routes[id] or nil end,
    }
end

-- --- counting what the policy did ------------------------------------------------------

-- One line for a report: how many runs the policy left out, and why.
function M.exclusions(evaluations)
    local out = { excluded = 0, counted = 0, by_reason = {}, negatives_excluded = 0 }
    for _, ev in ipairs(evaluations or {}) do
        for _, e in ipairs(ev.runs or {}) do
            if e.inclusion == LabEval.INCLUSION.EXCLUDED then
                out.excluded = out.excluded + 1
                out.by_reason[e.exclusion_reason] = (out.by_reason[e.exclusion_reason] or 0) + 1
                if e.answer == ResultCollector.ANSWERS.NEGATIVE then
                    out.negatives_excluded = out.negatives_excluded + 1
                end
            else
                out.counted = out.counted + 1
            end
        end
    end
    return out
end

return M
