-- =========================================================
-- tools/lua/confirm.lua - turns a sweep's trial log into the list of pairs the
-- GAME says connect.
--
--   lua tools/lua/confirm.lua [--character Zangief] [--scheme modern]
--                             [--trials <path>] [--out <dir>]
--                             [--min-attempts 2] [--unstable-ok true]
--
-- Needs Lua 5.4 and a trial log the sweep wrote. No game, no network.
-- =========================================================
--
-- WHY THIS EXISTS
--
-- The sweep writes one ce.trial.v1 per attempt and stops. Everything after that
-- - confirmed edges, verified combos, the KnowledgeDb export that publishes
-- them - was defined in Schema and produced by nothing. So the answer to "run
-- the sweep and what do I get" was: a log of attempts, and no list.
--
-- This is the first document in the chain that is about the GAME rather than
-- about the frame table. Every row in it rests on trials that ran.
--
-- WHAT IT IS CAREFUL ABOUT
--
-- Two things, and they are the same thing twice.
--
-- A pair whose trials all came back a_failed or inconclusive is NOT reported as
-- not linking. It is reported as still open. The sweep spent the time and
-- learned nothing, which is a different fact from learning that it does not
-- work, and only one of them should stop anybody re-running it.
--
-- A pair that linked once is not reported as reproduced. core/ConfirmedEdge.lua
-- holds that line; this tool reports how many rows it cost.
--
-- THE LICENCE SPLIT, WHICH IS WHY THE OUTPUT IS IN TWO HALVES
--
-- Everything here is measured from the game, so none of it is a derived work of
-- the frame data and none of it carries CC-BY-SA-4.0. That matters because the
-- plan is to publish it: a page of measured results can be licensed however its
-- author likes, and a page that also shows startup and on-hit numbers inherits
-- ShareAlike from the wiki (docs/NOTICE.md).
--
-- So the two are kept apart rather than joined into one convenient row. Joining
-- them here would mean anything downstream had to assume the stricter licence
-- for the whole file, whether it used the frame numbers or not.

local Cli = dofile("tools/lua/cli.lua")

local json          = dofile("tools/lua/json.lua")
local Characters    = dofile("tools/lua/characters.lua")
local ConfirmedEdge = require("func/ComboExplorer/core/ConfirmedEdge")
local Schema        = require("func/ComboExplorer/core/Schema")

-- --- arguments ---------------------------------------------------------------

local opt = Cli.args("confirm", arg, {
    character = "Zangief",
    scheme = "modern",
    min_attempts = nil,
    unstable_ok = false,
})

local entry, cerr = Characters.resolve(opt.character)
if not entry then Cli.die("confirm", tostring(cerr)) end
opt.character = entry.catalog
local char_lc = entry.catalog:lower()

opt.trials = opt.trials
    or ("reframework/data/ComboExplorer_data/trials/%s-%s.jsonl"):format(char_lc, opt.scheme)
opt.out = opt.out or ("confirmed/%s/%s"):format(char_lc, opt.scheme)

-- --- the log ------------------------------------------------------------------

local f = io.open(opt.trials, "r")
if not f then
    -- Not an error with a stack trace. The overwhelmingly likely reason is that
    -- the sweep has not been run yet, and the useful answer is how to get one.
    Cli.die("confirm", ("no trial log at %s\n\nThat file is written by the SWEEP panel on the "
        .. "machine running the game, one line per attempt. Run a sweep first, commit the "
        .. "log, and then this has something to read."):format(opt.trials))
end
local text = f:read("a")
f:close()

-- Decoded here rather than in ConfirmedEdge, which is pure and names no codec.
-- A line that will not decode is kept as a problem: a truncated last line is
-- what a crash leaves behind, and it means a trial ran whose result was lost -
-- which is not the same as a trial that never ran.
local records, bad_lines = {}, {}
local line_no = 0
for line in text:gmatch("[^\n]+") do
    line_no = line_no + 1
    local ok, rec = pcall(json.decode, line)
    if ok and type(rec) == "table" then
        records[#records + 1] = rec
    else
        bad_lines[#bad_lines + 1] = { line = line_no, text = line:sub(1, 80) }
    end
end

if #records == 0 then
    Cli.die("confirm", ("%s has %d line(s) and none of them decoded as a trial")
        :format(opt.trials, line_no))
end

-- --- fold ---------------------------------------------------------------------

local edges, problems, counts = ConfirmedEdge.from_trials(records, {
    min_attempts = tonumber(opt.min_attempts),
    unstable_ok = opt.unstable_ok == true,
})

-- Validated on the way out, not assumed. An edge the schema refuses is a bug in
-- the folding rather than a fact about the game, and it must not reach a file
-- that later gets published.
local refused = {}
for _, e in ipairs(edges) do
    local ok, vproblems = Schema.validate(Schema.KIND.CONFIRMED, e)
    if not ok then
        refused[#refused + 1] = { edge_id = e.edge_id,
                                  problem = vproblems and vproblems[1] and vproblems[1].problem }
    end
end

-- --- write --------------------------------------------------------------------

Cli.mkdir(opt.out)
local doc = {
    schema = "ce.confirmed_edges.v1",
    character = opt.character,
    control_scheme = opt.scheme,
    generated_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    source_log = opt.trials,
    counts = counts,
    edges = edges,
    problems = problems,
    refused_by_schema = refused,
    unreadable_lines = bad_lines,

    -- Stated rather than left to be worked out. Everything in this document was
    -- measured on the game; nothing in it is computed from the frame data, so
    -- the ShareAlike obligation that covers candidate-edges.json does not reach
    -- here. A page built from this file alone can be licensed by its author.
    licence_note = "Measured on Street Fighter 6. No value in this document is derived "
        .. "from the frame data, so it carries no CC-BY-SA obligation. Joining it to "
        .. "startup/on-hit figures - as a published page showing frame numbers would - "
        .. "does inherit one; see docs/NOTICE.md.",
}

local path = opt.out .. "/confirmed-edges.json"
local n, werr = json.save_file(path, doc, { indent = "  " })
if not n then Cli.die("confirm", ("could not write %s: %s"):format(path, tostring(werr))) end

-- --- the report ---------------------------------------------------------------

local rep = Cli.report()
local function say(fmt, ...) return rep:say(fmt, ...) end

say("# Confirmed edges - %s / %s", opt.character, opt.scheme)
say("")
say("EVERY ROW HERE WAS MEASURED ON THE GAME. This is the first document in the")
say("chain that is not a prediction: each one rests on trials that actually ran.")
say("")
say("- source log      %s", opt.trials)
say("- trials read     %d", counts.trials)
say("- pairs answered  %d", counts.edges)
say("")

say("## What the game said")
say("")
say("```")
say("%-12s %6d   the pair connects", "verified", counts.verified)
say("%-12s %6d   the pair does not", "rejected", counts.rejected)
say("%-12s %6d   still open - the trials ran and answered nothing", "pending", counts.pending)
say("%-12s %6d   of the above, reproduced rather than seen once", "stable", counts.stable)
say("```")
say("")

if counts.pending > 0 then
    say("`pending` is not a failure and must not be read as one. Those pairs came")
    say("back a_failed, wrong_move or inconclusive: move A never hit, or the pad")
    say("produced something else, so the link was never actually tested. They are")
    say("worth running again; a rejected pair is not.")
    say("")
end

local unstable = counts.verified - 0
do
    local n_unstable = 0
    for _, e in ipairs(edges) do
        if e.status == Schema.STATUS.VERIFIED and not e.stable then n_unstable = n_unstable + 1 end
    end
    unstable = n_unstable
end
if unstable > 0 then
    say("**%d verified pair(s) linked only once.** One attempt is not a reproduction,", unstable)
    say("so they are marked unstable and the schema will not accept them until")
    say("somebody says `--unstable-ok true` and means it. Running the sweep again")
    say("is the cheaper answer.")
    say("")
end

say("## Where the window was measured")
say("")
say("Which delays linked IS the execution window - the number core/Scoring.lua")
say("refuses to predict, because it can only be measured by sweeping it. The")
say("widest run below is over the delays that were TRIED, not over frames: a")
say("sweep that tried 2, 4 and 6 measured three points, not five.")
say("")

local with_window = {}
for _, e in ipairs(edges) do
    if e.window and e.window.count > 0 then with_window[#with_window + 1] = e end
end
table.sort(with_window, function(a, b)
    if a.window.count ~= b.window.count then return a.window.count > b.window.count end
    return a.edge_id < b.edge_id
end)

if #with_window == 0 then
    say("Nothing linked at any delay, so there is no window to report.")
else
    say("```")
    say("%-34s %6s %8s %8s", "pair", "width", "from", "to")
    for i = 1, math.min(#with_window, 20) do
        local e = with_window[i]
        say("%-34s %6d %8d %8d", e.edge_id, e.window.count, e.window.from, e.window.to)
    end
    say("```")
    if #with_window > 20 then
        say("")
        say("(%d more in confirmed-edges.json - this is the top 20 by width)", #with_window - 20)
    end
end
say("")

if #problems > 0 or #refused > 0 or #bad_lines > 0 then
    say("## What could not be read")
    say("")
    say("Nothing is dropped silently. A line that will not decode is a trial that")
    say("ran and whose result was lost, which is different from one that never ran.")
    say("")
    say("```")
    say("unreadable lines        %d", #bad_lines)
    say("records refused          %d", #problems)
    say("edges the schema refused %d", #refused)
    say("```")
    for _, r in ipairs(refused) do
        say("  %s: %s", tostring(r.edge_id), tostring(r.problem))
    end
    say("")
end

say("## What is still missing before any of this can be published")
say("")
say("A confirmed EDGE is a pair. A combo is a route, and ce.verified_combo.v1")
say("requires a MEASURED damage figure - which needs the route run on the game,")
say("not just its pairs. That is a second hardware pass and it does not exist")
say("yet. Until it does, this document is the end of the chain.")
say("")

say("## Written")
say("")
say("- %s  (%d bytes)", path, n)

local report_path = opt.out .. "/report.md"
local wrote, werr2 = rep:write(report_path)
print("")
if wrote then
    print(("written: %s"):format(report_path))
else
    print(("could not write %s: %s"):format(report_path, tostring(werr2)))
end
