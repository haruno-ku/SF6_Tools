-- =========================================================
-- tools/lua/labeval-cli.lua - distinct lab runs in (NDJSON on stdin),
-- evaluations out (NDJSON on stdout).
--
--   lua tools/lua/labeval-cli.lua [--policy ce-eval-v1] < runs.ndjson
--
-- Run from the repo root. tools/db/lab-eval.mjs is the caller: it merges the
-- labrows-cli rows into one per event_key, attaches every run_sources location,
-- and pipes them in. Needs Lua 5.4; no game, no network, no database.
-- =========================================================
--
-- Input lines: { kind = "run", event_key, sources = [...], ...labrows row }.
--
-- Output lines, each with a `kind`:
--   policy      the policy's key, version, description and rules (the data
--               lab.evaluation_policies stores)
--   evaluation  one per subject per cohort, as tools/lua/labeval.lua builds it
--   problem     a run or group that could not be evaluated, and why
--   summary     counts, last
--
-- Nothing else goes to stdout. The exit status is 1 when any problem was
-- written: an evaluation over part of its evidence would hash to an id that
-- looks as real as a complete one.

local Cli     = dofile("tools/lua/cli.lua")
local json    = dofile("tools/lua/json.lua")
local LabEval = dofile("tools/lua/labeval.lua")

local TOOL = "labeval-cli"
local opt = Cli.args(TOOL, arg, { policy = LabEval.DEFAULT_POLICY })

local function emit(row)
    io.stdout:write(json.encode(row), "\n")
end

local runs, problems = {}, 0
local n = 0
for line in io.stdin:lines() do
    n = n + 1
    if not line:match("^%s*$") then
        local ok, rec = pcall(json.decode, line)
        if not ok or type(rec) ~= "table" then
            problems = problems + 1
            emit({ kind = "problem", problem = ("input line %d does not decode"):format(n) })
        elseif rec.kind == "run" then
            runs[#runs + 1] = rec
        end
    end
end

local evaluations, found, policy = LabEval.evaluate(runs, { policy = opt.policy })
for _, p in ipairs(found or {}) do
    problems = problems + 1
    emit({ kind = "problem", problem = p })
end
if not evaluations then
    io.stderr:write(TOOL .. ": no evaluation was possible\n")
    os.exit(1)
end

emit({ kind = "policy", key = policy.key, version = policy.version,
       description = policy.description, rules = policy.rules })

-- An empty map is an object in the database, not a list (json.lua's default).
local function object(t)
    if type(t) == "table" and next(t) == nil then return json.EMPTY_OBJECT end
    return t
end

for _, ev in ipairs(evaluations) do
    local ms = ev.measured_summary
    ms.by_delay = object(ms.by_delay)
    ms.excluded_by_reason = object(ms.excluded_by_reason)
    emit(ev)
end

local t = LabEval.tally(evaluations)
emit({ kind = "summary", policy = policy.key, runs_in = #runs, evaluations = #evaluations,
       evaluation_runs = t.runs, problems = problems,
       by_result = object(t.by_result), by_kind_result = object(t.by_kind_result),
       excluded_by_reason = object(t.excluded_by_reason) })
os.exit(problems == 0 and 0 or 1)
