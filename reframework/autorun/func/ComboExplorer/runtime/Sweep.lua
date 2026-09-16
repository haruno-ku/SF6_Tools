-- =========================================================
-- ComboExplorer/runtime/Sweep.lua - runs a whole character's worklist, one
-- trial at a time, unattended. Owns the queue and the results file; owns no
-- judgement at all.
-- =========================================================
--
-- WHAT THIS IS FOR
--
-- Start it and walk away. Everything it needs to decide is decided elsewhere:
-- which pairs are worth a trial was settled offline by CandidateGenerator, what
-- a trial means was settled by LinkVerdict, and whether a result is worth
-- keeping was settled by ResultCollector. This file picks the next pair, hands
-- it to the Injector, and puts the answer where it belongs.
--
-- WHY THE PAIRS COME FROM A FILE
--
-- Because the machine running the game does not have what it would take to work
-- them out. install-dev.ps1 syncs only what is under reframework/, and the
-- frame data - the whole reason one pair is worth trying before another - lives
-- at data/frame-data/ on the dev machine. Computing candidates here would mean
-- computing them with no frame data at all: every pair low confidence, no
-- margins, no order.
--
-- So the order is shipped. `tools/lua/explore.lua --worklist` writes a compact
-- list under reframework/data/ComboExplorer_data/worklist/, sorted by
-- confidence, and this reads it. A sweep that is cut short has then spent its
-- time on the pairs the frame data had something to say about.
--
-- WHY IT CHECKS THE CATALOG CHECKSUMS
--
-- A worklist is a list of ACTION IDS, and an action id means nothing except
-- against the catalog it was generated from. Run one against a different build
-- and every pair is about some other move, silently. The checksums are in the
-- worklist for that reason and they are compared before the first trial, not
-- reported afterwards.
--
-- RESUME IS NOT WRITTEN HERE
--
-- core/ResultCollector.lua already does it: JSONL append, an index of what was
-- already run, and a truncated last line treated as "ran but lost the result"
-- rather than as done. This calls claim() and skips what comes back refused.

local ResultCollector = require("func/ComboExplorer/core/ResultCollector")
local Canonical       = require("func/ComboExplorer/core/Canonical")
local Timing          = require("func/ComboExplorer/core/Timing")
local SequenceCompiler = require("func/ComboExplorer/core/SequenceCompiler")
local Catalog         = require("func/ComboExplorer/core/Catalog")
local Provenance      = require("func/ComboExplorer/core/Provenance")
local JsonIO          = require("func/ComboExplorer/runtime/JsonIO")

local M = { name = "ComboExplorer.Sweep" }

-- Resolved on first use: the real Injector reaches GameAdapter, which calls sdk
-- at file scope. Tests pass their own.
local _injector = nil
local function default_injector()
    if _injector == nil then
        _injector = require("func/ComboExplorer/runtime/Injector")
    end
    return _injector
end

local run = nil

-- How many times a pair that asked to be retried may come back.
--
-- A retryable outcome is one the trial itself calls inconclusive - the stage
-- failed to reset, the injection gate shut mid-trial - so it deserves another
-- go. It does not deserve unlimited goes: a condition that fails every time
-- would otherwise turn a sweep into an infinite loop over one pair, which looks
-- exactly like a sweep making progress.
M.DEFAULT_MAX_ATTEMPTS = 3

-- How many consecutive failures TO START a trial end the sweep.
--
-- Distinct from a trial that ran and answered nothing. If the Injector will not
-- start - the gate is shut, the profile went away, the sink stopped writing -
-- then nothing is being measured and continuing only burns the operator's
-- evening. Stopping says so.
M.DEFAULT_MAX_START_FAILURES = 5

M.PROVENANCE = {
    max_attempts = "policy: how many times a retryable pair may come back",
    max_start_failures = "policy: consecutive refusals to start before giving up",
}

-- --- the worklist -----------------------------------------------------------

-- Returns the decoded worklist, or nil plus a reason. Separate from start() so
-- a caller can look at one without committing to a sweep.
function M.load_worklist(path, io_)
    io_ = io_ or JsonIO
    if type(path) ~= "string" or path == "" then return nil, "no worklist path" end
    local doc = io_.load(path)
    if type(doc) ~= "table" then
        return nil, ("no worklist at %s - generate one with "
            .. "`lua tools/lua/explore.lua --character <name> --worklist`"):format(path)
    end
    if doc.schema ~= "ce.worklist.v1" then
        return nil, ("%s is not a worklist (schema %s)"):format(path, tostring(doc.schema))
    end
    if type(doc.pairs) ~= "table" or #doc.pairs == 0 then
        return nil, ("%s has no pairs in it"):format(path)
    end
    return doc
end

-- --- which worklist -------------------------------------------------------------

-- The panel used to know one name: worklist/<char>-<scheme>.json. Two more kinds
-- now sit beside it, and running one meant renaming files on the game machine:
--
--   <char>-<scheme>.json              all    every candidate pair (explore.lua)
--   <char>-<scheme>-plan-<name>.json  plan   only the pairs the routes meeting a
--                                            plan's conditions need (plan.lua)
--   <char>-<scheme>-drc.json          drc    pairs through a Drive Rush Cancel,
--                                            set aside whole until DRC is
--                                            measured (#50)
--
-- Anything else in the directory - another character, another scheme, a file
-- somebody renamed to keep aside - is not offered. A name this does not parse is
-- a name nothing generated, and guessing what it holds is how a sweep ends up
-- about the wrong moves.
--
-- Order: all first, because it is the default and was the only choice before;
-- plans by name, so the list does not reshuffle between refreshes; drc last,
-- because running it presses nothing on this build.
--
-- `dir` is data-relative with forward slashes ("ComboExplorer_data/worklist").
-- The path handed back is rebuilt from it and the file's basename rather than
-- taken from the listing, so it is spelled exactly like the path the panel
-- always passed to load_worklist, whatever separators fs.glob reports.
--
-- fs_ : { glob = function(regex) -> { path, ... } }. JsonIO when nil. Passed by
-- tests, which is why nothing here names `fs`.
--
-- Returns the list, plus a reason when the directory could not be listed. The
-- all-pairs entry is ALWAYS in the list, first, even when the listing failed or
-- did not contain it: that is the file the panel has always tried, and its
-- absence is load_worklist's refusal to make ("no worklist at ... generate one
-- with explore.lua"), not a silently empty picker.
M.WORKLIST_KINDS = { all = 1, plan = 2, drc = 3 }

function M.list_worklists(dir, char_lc, scheme, fs_)
    local glob
    if fs_ == nil then
        glob = JsonIO.can_glob() and JsonIO.glob or nil
    else
        glob = fs_.glob
    end
    dir = tostring(dir or ""):gsub("[/\\]+$", "")
    char_lc = tostring(char_lc or ""):lower()
    scheme = tostring(scheme or ""):lower()
    local stem = char_lc .. "-" .. scheme

    local function entry(base, kind, plan_name)
        local e = { path = dir .. "/" .. base, name = base, kind = kind, plan_name = plan_name }
        if kind == "all" then e.label = "all pairs"
        elseif kind == "drc" then e.label = "drive rush cancel pairs (set aside)"
        else e.label = "plan: " .. plan_name end
        return e
    end

    local all = entry(stem .. ".json", "all")
    local out = { all }

    if not glob then
        all.unlisted = true
        return out, "fs.glob is unavailable, so only the all-pairs worklist can be offered"
    end

    -- FOUR backslashes in the source is two at runtime is one escaped separator
    -- in fs.glob's regex. See CatalogLocator.GLOB for the night one backslash
    -- short cost. gsub's replacement treats only % specially, so this is the
    -- same two characters per separator.
    local pattern = dir:gsub("/", "\\\\") .. "\\\\.*json"
    local ok, files = pcall(glob, pattern)
    if not ok or type(files) ~= "table" then
        all.unlisted = true
        return out, "could not list " .. dir
    end

    local seen, found_all, plans, drc = {}, false, {}, nil
    for _, p in ipairs(files) do
        local base = type(p) == "string" and p:match("([^/\\]+)$") or nil
        local lower = base and base:lower()
        -- Plain comparisons, not patterns: a character key could one day carry
        -- a character that means something to string.match.
        if lower and not seen[lower] and lower:sub(-5) == ".json"
            and lower:sub(1, #stem) == stem then
            seen[lower] = true
            local rest = lower:sub(#stem + 1, -6)
            if rest == "" then
                found_all = true
                all.path, all.name = dir .. "/" .. base, base
            elseif rest == "-drc" then
                drc = entry(base, "drc")
            elseif rest:sub(1, 6) == "-plan-" and #rest > 6 then
                plans[#plans + 1] = entry(base, "plan", base:sub(#stem + 7, -6))
            end
        end
    end
    if not found_all then all.missing = true end

    table.sort(plans, function(a, b) return a.plan_name < b.plan_name end)
    for _, e in ipairs(plans) do out[#out + 1] = e end
    if drc then out[#out + 1] = drc end
    return out
end

-- A plan's conditions as one line, keys in order so it reads the same each time.
function M.conditions_line(conditions)
    if type(conditions) ~= "table" or next(conditions) == nil then
        return "none - every route, ranked"
    end
    local keys = {}
    for k in pairs(conditions) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    local parts = {}
    for i, k in ipairs(keys) do
        local v = conditions[k]
        parts[i] = (v == true) and k or (k .. "=" .. tostring(v))
    end
    return table.concat(parts, ", ")
end

-- What is in one listed file: its pair count, and for a plan its conditions.
-- Read ONCE per entry - the result is kept on it - because the panel draws every
-- frame and a worklist is 100KB of JSON.
--
-- Never raises. A file that will not read, or reads as something other than a
-- worklist, stays in the list with `error` set: the operator sees it is there
-- and why it cannot run, rather than it vanishing or the panel dying. Starting
-- it still goes through load_worklist, which refuses it in its own words.
--
-- `mismatch` is a warning, not a refusal: the file's own character or control
-- scheme disagreeing with its name. The checksum check cannot catch that - one
-- catalog serves both schemes - and a classic list under a modern name would
-- sweep inputs the dummy is not set up for.
function M.describe_worklist(e, io_)
    if type(e) ~= "table" then return e end
    if e.described then return e end
    e.described = true
    io_ = io_ or JsonIO
    local ok, doc, why = pcall(io_.load, e.path)
    if not ok then
        e.error = "could not be read: " .. tostring(doc)
        return e
    end
    if type(doc) ~= "table" then
        e.error = e.missing and "not on this machine"
            or ("could not be read: " .. tostring(why or "missing or malformed"))
        return e
    end
    if doc.schema ~= "ce.worklist.v1" then
        e.error = ("not a worklist (schema %s)"):format(tostring(doc.schema))
        return e
    end
    e.count = type(doc.pairs) == "table" and #doc.pairs or 0
    if e.count == 0 then e.error = "has no pairs in it" end
    local plan = type(doc.plan) == "table" and doc.plan or nil
    if plan then
        e.conditions = M.conditions_line(plan.conditions)
        e.sort = plan.sort
        e.top = plan.top
    end
    local want_char, want_scheme = e.name:lower():match("^([^-]+)-([^-.]+)")
    local have_char = type(doc.character) == "string" and doc.character:gsub("[^%w_]", ""):lower()
    local have_scheme = type(doc.control_scheme) == "string" and doc.control_scheme:lower()
    if (have_char and want_char and have_char ~= want_char)
        or (have_scheme and want_scheme and have_scheme ~= want_scheme) then
        e.mismatch = ("the file says %s %s"):format(tostring(doc.character),
                                                    tostring(doc.control_scheme))
    end
    return e
end

-- The check that keeps a sweep from being about the wrong moves.
--
-- `catalog` is the one the game actually loaded. Returns true, or false plus a
-- reason naming which half disagrees.
function M.identity_matches(worklist, catalog)
    if type(worklist) ~= "table" or type(catalog) ~= "table" then
        return false, "nothing to compare"
    end
    for _, key in ipairs({ "ac_sha256", "bcm_sha256" }) do
        local want, have = worklist[key], catalog[key]
        if type(want) == "string" and type(have) == "string" and want ~= have then
            return false, ("the worklist was generated against a different catalog: "
                .. "%s is %s there and %s here"):format(key, want:sub(1, 12), have:sub(1, 12))
        end
    end
    return true
end

-- --- a pair, as a key and as a route -----------------------------------------

-- Above start() because start uses both: it checks every pair's route before
-- the first trial, and the queue below builds the same route to run it. One
-- builder, so the route that was checked is the route that runs.
--
-- A pair from a `-drc` worklist is A, then a Drive Rush Cancel, then B. It
-- names the same A and B as the direct pair and is a different question - B
-- out of a rush, not B out of A's recovery - so its key says so. Without the
-- marker the collector would read a DRC trial as the direct pair already
-- answered (or the other way round) and skip it. The direct key is left
-- exactly as it was: resume reads committed logs by that spelling.
local function is_drc(p)
    return p.via == SequenceCompiler.DRIVE_RUSH_STEP
end

local function pair_key(p)
    if is_drc(p) then
        return ("%d:%s->drc->%d:%s"):format(p.a_id, tostring(p.a_method),
                                            p.b_id, tostring(p.b_method))
    end
    return ("%d:%s->%d:%s"):format(p.a_id, tostring(p.a_method), p.b_id, tostring(p.b_method))
end

-- The DRC shape is three steps with the rush in the middle, the same shape
-- RouteSearch emits for a DRC edge, so a route checked here and a route found
-- offline are refused by SequenceCompiler for the same reason in the same
-- place. Today that refusal is certain: see SequenceCompiler's header for the
-- three things nobody has measured about pressing a Drive Rush.
local function pair_route(worklist, p)
    local a = { index = 1, action_id = p.a_id, input_method = p.a_method,
                notation = p.a_notation }
    if is_drc(p) then
        return {
            id = ("s-%d-drc-%d"):format(p.a_id, p.b_id),
            character = worklist.character,
            control_scheme = worklist.control_scheme,
            steps = {
                a,
                { index = 2, kind = SequenceCompiler.DRIVE_RUSH_STEP },
                { index = 3, action_id = p.b_id, input_method = p.b_method,
                  notation = p.b_notation },
            },
        }
    end
    return {
        id = ("s-%d-%d"):format(p.a_id, p.b_id),
        character = worklist.character,
        control_scheme = worklist.control_scheme,
        steps = {
            a,
            { index = 2, action_id = p.b_id, input_method = p.b_method,
              notation = p.b_notation },
        },
    }
end

-- --- starting ----------------------------------------------------------------

-- opts.worklist   : a decoded worklist, or use opts.path
-- opts.catalog    : the live catalog, for the identity check
-- opts.collector  : a ResultCollector. Required - a sweep that cannot record is
--                   a sweep that did not happen. It is handed to every trial as
--                   the Injector's sink, and the Injector is what writes to it
-- opts.provenance : the register, passed through to every trial
-- opts.injector   : substituted by tests
-- opts.delay      : ticks between A and B, one value for this pass
-- opts.delays     : one per gap, for a route with more than one. Either form is
--                   accepted and BOTH are used - this used to store `delays` and
--                   then read only `delay`, so a caller that passed a list got a
--                   sweep that ran at nil delay and skipped every pair while
--                   reporting itself finished
function M.start(opts)
    opts = opts or {}
    if run then return nil, "a sweep is already running" end

    local worklist = opts.worklist
    if worklist == nil and opts.path then
        local wl, werr = M.load_worklist(opts.path)
        if not wl then return nil, werr end
        worklist = wl
    end
    if type(worklist) ~= "table" then return nil, "no worklist" end

    if opts.catalog then
        local ok, why = M.identity_matches(worklist, opts.catalog)
        if not ok then return nil, why end
    end

    if type(opts.collector) ~= "table" then
        return nil, "no collector - a sweep that cannot record is a sweep that did not happen"
    end

    -- Refused, not ignored. The collector IS the sink (#45): every trial is
    -- written through it by the Injector, once. A caller still passing a path
    -- here believes the rows go there as well, and before #45 the panel passed
    -- the same file as both - which, the day the sink started writing, would
    -- have put every row in it twice.
    if opts.sink ~= nil then
        return nil, "a sweep records through its collector, which every trial is "
            .. "handed as its sink - a second sink would be a second writer, and "
            .. "a second writer is every row twice"
    end

    -- Refused rather than defaulted, and the failure it prevents is the nastiest
    -- kind available here. The delay is part of a trial's identity, so with none
    -- the collector cannot build a key, every claim comes back refused, every
    -- pair is counted as skipped, and the sweep reports itself FINISHED having
    -- pressed nothing. A night that looks like a completed pass and contains no
    -- measurements is worse than one that stopped at the first pair.
    --
    -- SequenceCompiler refuses an absent delay for the same reason and says it
    -- in its own header: "a default would be a guess, and a guess that produces
    -- a working-looking program is the worst kind".
    if type(opts.delay) ~= "number" and type(opts.delays) ~= "table" then
        return nil, "no delay - how long to wait between the two moves is what a "
            .. "sweep measures, and without it every trial would be skipped and "
            .. "the sweep would report itself finished having pressed nothing"
    end

    -- The worklist names action ids the CATALOG chose within a notation group;
    -- the register knows which of them the button actually produces on this
    -- build. Applied here, once, before the first trial - see
    -- core/Canonical.lua for why it is not applied when the worklist is
    -- generated, and for the 148 pairs that could not have succeeded without
    -- it.
    --
    -- Failure is not fatal on its own: an operator may be sweeping before the
    -- calibration has run, and a sweep against the shipped ids is still a
    -- sweep. What must not happen is it being silent, so the reason rides on
    -- the run and the panel prints it.
    local canonical, cwhy = nil, nil
    if opts.provenance then
        canonical, cwhy = Provenance.value(opts.provenance, "action_id_canonical")
    else
        cwhy = "no provenance register was given"
    end

    local creport = nil
    if canonical then
        local folded, rep = Canonical.apply(worklist, canonical)
        if folded then
            worklist, creport = folded, rep
        else
            cwhy = tostring(rep)
        end
    end

    -- Pairs the compiler cannot play are set aside before the first trial, not
    -- run and recorded. Run, they compile, press something that produces
    -- nothing, and write "move B never appeared" - a confident row about a
    -- link nobody tested, which is the one kind of row this suite exists not to
    -- write (#49). Set aside, they are listed with their reason, so the pair
    -- count on the panel says why it is smaller than the file.
    --
    -- context_known comes from the pair, and only the pair. The worklist used
    -- to cross every starter with every follow-up, so nothing vouched that a
    -- follow-up came after its own move and this was hard-coded false. Now
    -- explore.lua writes context_known = true on exactly the pairs whose parent
    -- the frame source names ("5MP~MP" makes MP the parent of ">MP"), and
    -- CandidateGenerator no longer produces a follow-up after a move the source
    -- says it does not come out of. A follow-up whose parent nobody names still
    -- arrives without the field and is still set aside here - absent is not a
    -- vouch, and `== true` keeps a stray string from becoming one.
    --
    -- Every Drive Rush Cancel pair lands here as well, as kind drive_rush, and
    -- nothing about it is computed first: no delay, no expected ids, no claim.
    -- delay_for would find A's frames and happily predict a gap for a press
    -- that cannot be made, and a predicted gap on a pair that never ran is a
    -- number that looks like it meant something.
    -- The measured Classic map, or nil. Provenance.value withholds the
    -- provisional value on purpose, so this is nil on every build where no
    -- calibration has run under Classic - and then every classic pair is set
    -- aside by name, which is what it was before one could be. After such a run
    -- it is the six bits that were witnessed, and a classic pair is set aside
    -- only when it presses a button that is not among them.
    local classic_bits = opts.provenance
        and Provenance.value(opts.provenance, "classic_button_bits") or nil

    local playable, unplayable = {}, {}
    for _, p in ipairs(worklist.pairs or {}) do
        local found = SequenceCompiler.unplayable(pair_route(worklist, p),
                                                  { context_known = p.context_known == true,
                                                    button_bits = classic_bits })
        if #found == 0 then
            playable[#playable + 1] = p
        else
            -- The first problem, unless one of them is a reason no fix to the
            -- pair can get round. A DRC pair whose A also repeats a direction
            -- would otherwise be counted as a 22-style repeat, and fixing the
            -- repeat would then look like it would make the pair playable when
            -- the rush still could not be pressed; a classic pair is the same
            -- case with an unwitnessed button map in place of the rush. The
            -- order lives in SequenceCompiler, beside the kinds themselves.
            local pick = SequenceCompiler.principal_unplayable(found)
            unplayable[#unplayable + 1] = { pair = pair_key(p), kind = pick.kind,
                                            reason = pick.reason }
        end
    end
    if #unplayable > 0 then
        local copy = {}
        for k, v in pairs(worklist) do copy[k] = v end
        copy.pairs = playable
        worklist = copy
    end

    run = {
        injector = opts.injector or default_injector(),
        worklist = worklist,
        -- Passed straight through to every Injector.start. Sweep owns no
        -- judgement about the stage; it only has to hand every trial the same
        -- one, because a sweep whose trials ran under different setups is not
        -- one dataset.
        stage_cfg = opts.stage_cfg,
        -- For Catalog.group_ids as well as the identity check.
        catalog = opts.catalog,
        -- For Timing. The buffer is unverified, and the sweep is allowed to use
        -- the guess for the same reason the calibration sweep is: it is testing
        -- the window, not trusting it.
        buffer_ticks = opts.buffer_ticks,
        hold_ticks = opts.hold_ticks,
        canonical_report = creport,
        canonical_why = (creport == nil) and tostring(cwhy or "unavailable") or nil,
        -- Set aside before the first trial. See the comment where they are found.
        unplayable = unplayable,
        collector = opts.collector,
        provenance = opts.provenance,
        delay = opts.delay,
        delays = opts.delays,
        allow_injection = opts.allow_injection,

        max_attempts = opts.max_attempts or M.DEFAULT_MAX_ATTEMPTS,
        max_start_failures = opts.max_start_failures or M.DEFAULT_MAX_START_FAILURES,

        index = 1,              -- where in worklist.pairs we are
        front = {},             -- pairs with another gap to try, taken first
        plans = {},             -- key -> { steps, next }: see M.plan_for
        by_prediction = {},     -- trials started, by which timing chose the gap
        requeued = {},          -- pairs asking for another go, taken after the list
        attempts = {},          -- key -> how many times it has been tried
        started = 0,
        finished = 0,
        skipped = 0,
        start_failures = 0,
        consecutive_start_failures = 0,
        problems = {},
        done = false,
        stopped_because = nil,
    }
    return true
end

function M.stop() run = nil end
function M.running() return run ~= nil end

-- --- the queue ---------------------------------------------------------------

-- The next pair to try, or nil when there is nothing left. Requeued pairs come
-- AFTER the whole list rather than immediately: whatever made one inconclusive
-- is more likely to have passed by the time the list has been round once.
--
-- A pair with more gaps still to try comes back FIRST, before the list moves
-- on: the gaps of one pair are one question (see M.plan_for), and a pair that
-- has answered it at its first gap does not come back at all.
--
-- The second value says where the pair came from. A pair taken fresh from the
-- list starts its plan from the beginning; one from `front` or `requeued` picks
-- its plan up where it was left.
local function next_pair()
    local f = table.remove(run.front, 1)
    if f ~= nil then return f, "front" end
    local p = run.worklist.pairs[run.index]
    if p ~= nil then
        run.index = run.index + 1
        return p, "list"
    end
    return table.remove(run.requeued, 1), "requeued"
end

local function route_for(p)
    return pair_route(run.worklist, p)
end

-- --- one frame ---------------------------------------------------------------

-- Driven from Clock.on_frame beside the other machines. Returns whatever the
-- Injector's tick returned, or nil on a frame where nothing was driven.
-- The gap this pair is run at, and where it came from.
--
-- Separate and public so a caller can see what the sweep would do before it
-- does it, and so the fallback is visible rather than a number appearing from
-- nowhere.
--
-- The first gap of M.plan_for, kept under its old name and shape because the
-- panel and the tests read it.
function M.delay_for(p, r)
    local steps = M.plan_for(p, r)
    return steps[1].delay, steps[1].why
end

-- How a pair's B has to be pressed, and where that word came from.
--
-- The worklist says it as `mechanism` (CandidateGenerator.mechanism). A
-- worklist written before that field existed does not, and one thing about it
-- can still be read without guessing: a KNOWN negative margin keeps frame_link
-- off an edge's reasons, so a pair that is in the list with one is there for a
-- cancel and nothing else. Anything else unlabelled is timed as a link, as
-- every pair was before, and says it was not told.
function M.mechanism_of(p)
    if type(p.mechanism) == "string" then return p.mechanism, "worklist" end
    if type(p.margin_frames) == "number" and p.margin_frames < 0 then
        return "cancel", "inferred: a known negative margin rules out frame_link"
    end
    return "unknown", "the worklist does not say"
end

-- Every gap this pair is to be run at, in order, each with the reason for it.
--
-- WHY A PAIR CAN HAVE MORE THAN ONE GAP NOW
--
-- A link has one gap the frame data states directly: A has just become free.
-- A cancel does not. Its window opens when A hits, which the frame data does
-- give, and ends at a point the frame data does not carry and nobody has
-- measured - so it is searched over Timing.cancel_window's grid rather than
-- pressed once at a number that would look like a prediction.
--
-- WHICH TIMING, FOR WHICH PAIR
--
--   cancel : the cancel grid alone. A link timing on a pair with no link
--            margin presses after A has recovered, where no cancel exists -
--            which is how the first framedata sweep ran every one of them.
--   both   : the cancel grid FIRST, then the link gap. In the committed rows
--            a cancelled B came out at the end of A's hitstop wherever in the
--            hitstop it was pressed, while a link has one gap and a few ticks
--            of buffer; and an on-hit advantage big enough to link is as often
--            a knockdown. The cheaper, sturdier question goes first, and the
--            link is still asked if it says no.
--   link, unknown : the link gap, as before.
--
-- The plan stops at the first gap that links (M.finish_trial), so a pair that
-- answers early costs one trial.
--
-- Each step's `why` carries `predicted` as before, plus `timing`: the compact
-- record that travels onto the trial row, so a negative can be read later as
-- "measured at a cancel timing" or "measured at a link timing".
function M.plan_for(p, r)
    r = r or run or {}
    local hold = r.hold_ticks or 3
    local mechanism, mech_source = M.mechanism_of(p)

    -- B's motion before its button. See Timing's header for the rows that
    -- showed the model was pressing a 720 ten ticks late.
    local lead = Timing.motion_ticks(p.b_notation)
    local lead_known = lead ~= nil
    if lead == nil then lead = 0 end

    local a = { startup = p.a_startup, active = p.a_active, recovery = p.a_recovery,
                hitstop = p.a_hitstop, hitstun = p.a_hitstun }
    local b = { startup = p.b_startup }

    local function timing(prediction, extra)
        local t = { mechanism = mechanism, mechanism_source = mech_source,
                    prediction = prediction, b_motion_ticks = lead,
                    b_motion_known = lead_known }
        for k, v in pairs(extra or {}) do t[k] = v end
        return t
    end

    local steps = {}
    local missing_all = {}

    if mechanism == "cancel" or mechanism == "both" then
        local cw, cmissing = Timing.cancel_window(a, b, { hold_ticks = hold,
                                                         b_motion_ticks = lead })
        if cw then
            for i, g in ipairs(cw.gaps) do
                steps[#steps + 1] = {
                    delay = g,
                    why = { predicted = true, prediction = "cancel", window = cw,
                            timing = timing("cancel", {
                                point = i, points = #cw.gaps,
                                appears_at = cw.basis.appears_at,
                                in_hitstop = cw.basis.in_hitstop,
                                bound_at = cw.basis.bound_at,
                                bound_status = cw.basis.bound_status,
                                late_at_zero = cw.late_at_zero,
                                past_bound_at_zero = cw.past_bound_at_zero,
                            }) },
                }
            end
        else
            for _, m in ipairs(cmissing or {}) do missing_all[#missing_all + 1] = m end
        end
    end

    if mechanism ~= "cancel" then
        local w, missing = Timing.window(a, b, {
            hold_ticks = hold,
            buffer_ticks = r.buffer_ticks,
            b_motion_ticks = lead,
        })
        if w then
            local dup = false
            for _, s in ipairs(steps) do if s.delay == w.latest then dup = true end end
            if not dup then
                steps[#steps + 1] = {
                    delay = w.latest,
                    why = { predicted = true, prediction = "link", window = w,
                            timing = timing("link", { earliest = w.earliest,
                                                      latest = w.latest,
                                                      whiff_after = w.whiff_after,
                                                      free_at = w.basis.free_at }) },
                }
            end
        else
            for _, m in ipairs(missing or {}) do missing_all[#missing_all + 1] = m end
        end
    end

    -- A route with several gaps is run at the operator's list, which
    -- SequenceCompiler prefers over any one delay; a grid over the one delay
    -- it ignores would be the same trial run again under different keys.
    if type(r.delays) == "table" and #steps > 1 then steps = { steps[1] } end

    if #steps > 0 then return steps end

    -- No window. The pair still runs, at whatever the operator set, and the row
    -- says the gap was NOT predicted - a negative measured at an unpredicted
    -- gap is not evidence that the pair does not link.
    -- What it actually saw, not only what it wanted. "missing: a.recovery" and
    -- "missing: nothing, and still no window" send an operator to different
    -- places, and the first run of this printed "no reason given" - which sent
    -- me guessing at the code instead of reading the data.
    local saw = ("startup=%s active=%s recovery=%s hitstop=%s b=%s buffer=%s"):format(
        tostring(p.a_startup), tostring(p.a_active), tostring(p.a_recovery),
        tostring(p.a_hitstop), tostring(p.b_startup), tostring(r.buffer_ticks))
    return { {
        delay = r.delay,
        why = { predicted = false, missing = missing_all, saw = saw,
                timing = timing("none", { missing = missing_all }) },
    } }
end

function M.tick()
    if not run or run.done then return nil end
    local inj = run.injector

    -- A trial in flight owns the frame.
    if inj.running() then
        local cmd = inj.tick()
        if cmd and cmd.outcome ~= nil then M.finish_trial() end
        return cmd
    end

    -- Otherwise start the next one.
    local p, from = next_pair()
    if p == nil then
        run.done = true
        run.stopped_because = "the worklist is finished"
        return nil
    end

    -- WHEN to press the second move, from the frames the worklist now carries.
    --
    -- This used to be run.delay for every pair - 4, because that is the panel's
    -- default and nothing else was available. At gap 4 the second input lands
    -- inside the first move's animation: a cancel window. Measured on build
    -- 24176760, one real pair's LINK window was gap 40..44, and the sweep's 202
    -- rows found 8 links, all of them Super Arts, which are the only thing that
    -- connects out of a cancel window (#46).
    --
    -- `latest` rather than the middle of the window: it is the gap at which A
    -- has just become free, which is the one the frame data states directly.
    -- The earlier end depends on the input buffer, which is unverified.
    -- gap_why, not `why`: this function already has a `why` from
    -- ResultCollector.claim below, and naming this one the same shadowed it.
    -- The claim's why is nil on success, so every predicted gap was counted as
    -- a fallback while the predicted delay was being used - the sweep said
    -- "0 predicted" and pressed at 69 anyway.
    --
    -- A pair's gaps are a plan now (M.plan_for): one gap for a link, a grid for
    -- a cancel. A pair fresh from the list gets a fresh plan; one coming back
    -- for its next gap, or for a retry, carries on where it was.
    local key = pair_key(p)
    local plan = run.plans[key]
    if plan == nil or from == "list" then
        plan = { steps = M.plan_for(p, run), next = 1 }
        run.plans[key] = plan
    end
    local step = plan.steps[plan.next]
    if step == nil then return nil end
    local delay, gap_why = step.delay, step.why
    -- Attempts are counted per gap. The same pair at another gap is not a
    -- second attempt at the same trial, and the collector keys it apart anyway.
    local akey = ("%s@%s"):format(key, tostring(delay))
    -- ResultCollector.delay_list accepts a number or a list, so whichever form
    -- the caller gave is handed through unchanged. Reading `run.delay` alone
    -- here was the bug: with a list supplied, this key was built from nil, the
    -- claim was refused, and the pair counted as skipped.
    local spec_for_claim = {
        edge_id = key, attempt = (run.attempts[akey] or 0) + 1,
        delay = run.delays or delay,
    }
    -- Skipping is the collector's decision, not this file's: it is the one that
    -- read the previous run's file and knows what is already answered.
    local may, why = ResultCollector.claim(run.collector, spec_for_claim)
    if not may then
        run.skipped = run.skipped + 1
        run.last_skip = ("%s: %s"):format(key, tostring(why))
        -- A gap answered in an earlier session. If it linked, the question
        -- this plan asks is answered; otherwise the next gap is still open.
        local prior = nil
        local rkey = ResultCollector.key(spec_for_claim)
        if rkey and run.collector.resume and run.collector.resume.done then
            prior = run.collector.resume.done[rkey]
        end
        M._advance(p, plan, prior ~= nil and prior.verdict == "link")
        return nil
    end

    if gap_why and gap_why.predicted then
        run.predicted = (run.predicted or 0) + 1
    else
        run.unpredicted = (run.unpredicted or 0) + 1
        -- WHICH field was missing, kept for the panel. "0 predicted" with no
        -- reason is a number an operator can only guess at, and guessing at it
        -- is what this whole suite is built to avoid.
        run.unpredicted_why = ((gap_why and gap_why.missing
            and table.concat(gap_why.missing, ", ")) or "nothing named")
            .. "  |  " .. tostring(gap_why and gap_why.saw)
    end
    local prediction = gap_why and gap_why.timing and gap_why.timing.prediction or "none"
    run.by_prediction[prediction] = (run.by_prediction[prediction] or 0) + 1
    run.attempts[akey] = (run.attempts[akey] or 0) + 1
    run.current = p
    run.current_key = key
    run.current_akey = akey
    run.current_plan = plan

    local ok, err = inj.start({
        provenance = run.provenance,
        allow_injection = run.allow_injection,
        route = route_for(p),
        delay = delay,
        delays = run.delays,
        -- The whole notation group, not the one id the worklist names. See
        -- Catalog.group_ids: 105 of this sweep's 216 rows came back "saw action
        -- id(s) N instead" on the OTHER member of the same group.
        expected = {
            [1] = Catalog.group_ids(run.catalog, p.a_id,
                { input_method = p.a_method, notation = p.a_notation }),
            [2] = Catalog.group_ids(run.catalog, p.b_id,
                { input_method = p.b_method, notation = p.b_notation }),
        },
        edge_id = key,
        attempt = run.attempts[akey],
        -- Which timing this gap came from - cancel grid, link, or none - onto
        -- the row. A negative at a link gap on a cancel-only pair says nothing
        -- about the cancel, and a reader can only tell if the row says so.
        timing = gap_why and gap_why.timing or nil,
        -- The collector, as the sink. The Injector writes the row on the tick
        -- the verdict exists and finish_trial only reads whether it landed:
        -- one writer, so one row per trial.
        sink = { collector = run.collector },
        -- The same override every trial in this sweep runs under. It also
        -- scopes the resume, through Injector.conditions_for: a pair answered
        -- with the fighters 300 apart has not been answered with them in
        -- range, and skipping it as done would be the sweep believing a
        -- whiffed trial.
        stage_cfg = run.stage_cfg,
    })

    if not ok then
        run.start_failures = run.start_failures + 1
        run.consecutive_start_failures = run.consecutive_start_failures + 1
        run.problems[#run.problems + 1] = { pair = key, reason = tostring(err) }
        -- Nothing is being measured. Continuing only burns the evening.
        if run.consecutive_start_failures >= run.max_start_failures then
            run.done = true
            run.stopped_because = ("%d trials in a row would not start - last reason: %s")
                :format(run.consecutive_start_failures, tostring(err))
        end
        -- The rest of the plan goes with it, as the pair always did.
        run.current, run.current_key, run.current_akey, run.current_plan = nil, nil, nil, nil
        return nil
    end

    run.consecutive_start_failures = 0
    run.started = run.started + 1
    return nil
end

-- Record the finished trial and decide whether its pair comes back.
--
-- Separate from tick() so a test can drive it directly, and because the two
-- decisions in it - what to record, and what to retry - are the only judgement
-- this file makes.
function M.finish_trial()
    if not run then return nil, "no sweep" end
    local inj = run.injector
    local result = inj.result()
    local key = run.current_key

    -- Already written, by the Injector, through run.collector (#45). Writing
    -- it here as well was the obvious thing and would be every row twice. What
    -- is left is to make a failed write visible, because a pair whose row did
    -- not land has not been answered, whatever its verdict was.
    if result and result.record_error then
        run.problems[#run.problems + 1] = {
            pair = key, reason = "the result would not record",
            detail = result.record_error,
        }
    end

    -- A trial that answered nothing may come back, up to a bound. `retryable`
    -- is the runner's own word for it - a stage that failed to reset, a gate
    -- that shut mid-trial - and it is deliberately not re-derived here.
    local trial = result and result.trial
    local akey = run.current_akey or key
    if trial and trial.retryable and run.current then
        if (run.attempts[akey] or 0) < run.max_attempts then
            -- The same gap again: the plan does not move on for a trial that
            -- answered nothing.
            run.requeued[#run.requeued + 1] = run.current
        else
            run.problems[#run.problems + 1] = {
                pair = key,
                reason = ("gave up after %d attempts"):format(run.max_attempts),
            }
            if run.current_plan then M._advance(run.current, run.current_plan, false) end
        end
    elseif run.current and run.current_plan then
        -- The plan's second decision: a gap that linked answers the pair, and
        -- anything else leaves the next gap to be tried.
        M._advance(run.current, run.current_plan, trial ~= nil and trial.verdict == "link")
    end

    run.finished = run.finished + 1
    run.current, run.current_key, run.current_akey, run.current_plan = nil, nil, nil, nil
    inj.stop()
    return true
end

-- Moves a pair's plan to its next gap and, if there is one, puts the pair at
-- the front of the queue for it. A gap that linked ends the plan. Exposed with
-- an underscore for the tick above and for tests, not as an API.
function M._advance(p, plan, answered)
    if not run or type(plan) ~= "table" then return end
    plan.next = answered and (#plan.steps + 1) or (plan.next + 1)
    if plan.steps[plan.next] ~= nil then
        run.front[#run.front + 1] = p
    end
end

-- --- readouts ----------------------------------------------------------------

function M.progress()
    if not run then return nil end
    local total = #run.worklist.pairs
    return {
        character = run.worklist.character,
        index = math.min(run.index - 1, total),
        total = total,
        requeued = #run.requeued,
        started = run.started,
        finished = run.finished,
        skipped = run.skipped,
        start_failures = run.start_failures,
        problems = #run.problems,
        done = run.done,
        stopped_because = run.stopped_because,
        current = run.current_key,
        last_skip = run.last_skip,
        -- What the register did to this list. Shown while it runs, because
        -- "230 / 230" against a 378-pair file needs its reason next to it or it
        -- reads as a truncated worklist.
        canonical = run.canonical_report
            and Canonical.summary(run.canonical_report) or nil,
        canonical_why = run.canonical_why,
        -- How many gaps came from the frame data and how many fell back.
        -- A run that is mostly fallback is a run measuring the wrong
        -- thing, and it should be visible while it happens.
        predicted = run.predicted or 0,
        unpredicted = run.unpredicted or 0,
        -- The same trials split by WHICH prediction: link, cancel or none.
        by_prediction = run.by_prediction,
        -- Gaps still queued for pairs part-way through their plan.
        pending_gaps = #run.front,
        unpredicted_why = run.unpredicted_why,
        -- Not tried, and why. Counted apart from `skipped`, which is pairs
        -- already answered: these were never going to produce an answer.
        unplayable = #run.unplayable,
        unplayable_by_kind = (function()
            local by = {}
            for _, u in ipairs(run.unplayable) do by[u.kind] = (by[u.kind] or 0) + 1 end
            return by
        end)(),
    }
end

function M.result()
    if not run then return nil end
    local p = M.progress()
    p.summary = ResultCollector.summary(run.collector)
    p.problem_detail = run.problems
    p.unplayable_detail = run.unplayable
    return p
end

return M
