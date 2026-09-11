-- =========================================================
-- ComboExplorer/core/ResultCollector.lua - one trial per line, appended as it
-- happens, and the index that lets an interrupted sweep pick up where it
-- stopped. Pure: formatting, parsing and the index are functions, and the file
-- handle and the codec are injected.
-- =========================================================
--
-- WHY LINES AND NOT A DOCUMENT
--
-- A full A->B sweep is thousands of trials and about an hour on the machine
-- that has the game. In that hour the game will be closed, a round will end, or
-- Windows will decide it is time to restart. A document assembled in memory and
-- written at the end loses the whole hour when that happens. A file that is one
-- complete record per line loses at most the line that was in flight.
--
-- The terminator is therefore part of the record and not decoration the writer
-- adds afterwards. If the newline were the writer's business then "the record
-- was written" and "the record is complete" would be two different events, and
-- everything below depends on them being one.
--
-- WHAT A TRUNCATED LAST LINE MEANS
--
-- It means "a trial ran and its result was lost", not "this trial never ran".
-- A line is only formatted once a verdict exists - the schema will not accept a
-- trial record without one - so a half-written line is the tail of a finished
-- trial, never the head of one that was about to start.
--
-- The two facts call for different things, which is why the distinction is
-- worth the code. A lost result has to be re-run before it exists again, so the
-- truncated tail must not satisfy a resume claim. And the operator has to be
-- told that the hour came up one trial short, rather than handed a file that
-- silently parses clean.
--
-- A truncated tail is therefore reported, is never indexed, and is NOT parsed
-- even when it happens to decode. A fragment that got as far as its verdict
-- field is still a fragment; believing one is how a partial write becomes a
-- permanent fact.
--
-- WHAT THE RESUME KEY HAS TO BE
--
-- Two ways to get this wrong, both silent. Too coarse a key and the resumed
-- sweep skips a trial it never ran, leaving a hole nothing downstream can see.
-- Too fine a key and it re-runs the hour it already paid for.
--
-- The key is the subject, the WHOLE delay vector, and the attempt number.
--
-- The whole vector, because a three-step route at delays {3,5} and the same
-- route at {4,5} are different programs and neither is an answer about the
-- other - keying on the swept gap alone would skip the second one for ever.
-- The attempt number, because repeats are the only thing that separates a link
-- that reproduces from one that happened once, and collapsing them would leave
-- the sweep believing one attempt was three.
--
-- Everything else that changes what a trial MEANS - character, control scheme,
-- game patch, the calibration the button map came from - is identity rather
-- than key. A line whose identity does not match the run being resumed is
-- counted and reported but never satisfies a claim: a result measured under a
-- different calibration is not an answer to this run's question, and skipping
-- on one is the silent-hole failure wearing a disguise.
--
-- A VERDICT IS NOT A STATUS
--
-- `link` is a verified edge and `whiff` is a rejected one, but `a_failed`,
-- `wrong_move` and `inconclusive` are neither: they are trials that ran and
-- answered nothing, because A never hit or because the pad produced some other
-- move. Recording those as `rejected` would turn missing information into a
-- negative result, and a negative result is the thing that stops anybody ever
-- testing the pair again.
--
-- They are recorded as `runtime_pending` instead - the trial happened, the
-- question has not been answered - and the mapping is derived here rather than
-- accepted from a caller, because it is exactly the sort of thing a caller gets
-- wrong once, quietly, three thousand rows deep.
--
-- WHAT IS INJECTED
--
--   append(line)  writes the line verbatim and returns true, or false/nil and
--                 a reason. A writer that returns nothing counts as having
--                 failed: believing a write that did not happen is worse than
--                 one spurious re-run.
--   encode(rec)   a table to one line of text. No json module is named here.
--   decode(text)  one line of text back to a table, for resume.
--   flush()       optional, called every `flush_every` writes. The default is
--                 every line, because a buffer holding the last twenty results
--                 is exactly the twenty results a crash takes.

local Schema = require("func/ComboExplorer/core/Schema")
local LinkVerdict = require("func/ComboExplorer/core/LinkVerdict")
local SequenceCompiler = require("func/ComboExplorer/core/SequenceCompiler")

local M = { name = "ComboExplorer.ResultCollector" }

M.KIND = Schema.KIND.TRIAL

local V = LinkVerdict.VERDICT

M.ANSWERS = {
    POSITIVE   = "positive",    -- the game said yes
    NEGATIVE   = "negative",    -- the game said no, and said it about the link
    UNANSWERED = "unanswered",  -- the trial ran and the question is still open
}

-- What a verdict says about the LINK, which is not what it says about the
-- trial. A wrong move came out: that is a fact about the input, not evidence
-- that A does not link into B.
M.MEANING = {
    [V.LINK]         = M.ANSWERS.POSITIVE,
    [V.BLOCKED]      = M.ANSWERS.NEGATIVE,
    [V.WHIFF]        = M.ANSWERS.NEGATIVE,
    [V.COMBO_BROKE]  = M.ANSWERS.NEGATIVE,
    [V.WRONG_MOVE]   = M.ANSWERS.UNANSWERED,
    [V.A_FAILED]     = M.ANSWERS.UNANSWERED,
    [V.INCONCLUSIVE] = M.ANSWERS.UNANSWERED,
}

M.STATUS_FOR = {
    [M.ANSWERS.POSITIVE]   = Schema.STATUS.VERIFIED,
    [M.ANSWERS.NEGATIVE]   = Schema.STATUS.REJECTED,
    [M.ANSWERS.UNANSWERED] = Schema.STATUS.RUNTIME_PENDING,
}

-- The fields that decide whether two trials are about the same question. Not
-- part of the key - see the banner - but a filter on which lines a resume may
-- believe.
M.IDENTITY_FIELDS = {
    "character", "control_scheme", "game_patch", "calibration_id", "conditions",
}

-- --- the vocabulary ----------------------------------------------------------

-- An unrecognised verdict is refused rather than filed under "unanswered". A
-- verdict added upstream and not taught to this module would otherwise be
-- absorbed silently, and if it were a negative one the sweep would lose it.
function M.classify(verdict)
    local m = M.MEANING[verdict]
    if m == nil then
        return nil, ("unknown verdict %q - a verdict this module cannot classify "
            .. "cannot be given a status, and guessing one either invents a "
            .. "negative result or hides a real one"):format(tostring(verdict))
    end
    return m
end

function M.status_for(verdict)
    local m, why = M.classify(verdict)
    if not m then return nil, why end
    return M.STATUS_FOR[m]
end

-- --- the key -----------------------------------------------------------------

-- Works on a spec and on a decoded record, because they carry the same fields.
-- One spelling of the rule means the key computed before a trial runs is the
-- same string the resume reads back afterwards - which is the only reason
-- resume works at all.
function M.subject(t)
    if type(t) ~= "table" then return nil, "not a trial" end

    local s = t.subject
    if type(s) == "table" then
        if s.kind ~= "edge" and s.kind ~= "route" then
            return nil, "a trial is about an edge or a route"
        end
        if type(s.id) ~= "string" or s.id == "" then
            return nil, "the subject has no id"
        end
        return { kind = s.kind, id = s.id }
    end

    local route = (type(t.route_id) == "string" and t.route_id ~= "") and t.route_id or nil
    local edge = (type(t.edge_id) == "string" and t.edge_id ~= "") and t.edge_id or nil
    if route and edge then
        -- Which one the key was built from would be a coin flip, and a coin
        -- flip in the key is a resume that skips the wrong trials.
        return nil, "a trial names an edge or a route, not both"
    end
    if route then return { kind = "route", id = route } end
    if edge then return { kind = "edge", id = edge } end
    return nil, "a trial has to name the edge or the route it is about"
end

-- Normalises whatever the caller called the delay into the list the key is
-- built from. `#` is never used on the incoming table: a decoded [4,null,6] has
-- a hole, and the length of a table with a hole is undefined - exactly the case
-- that would produce a short, colliding key.
function M.delay_list(d)
    if type(d) == "number" then d = { d } end
    if type(d) ~= "table" then
        return nil, "a trial has to say what delay it ran at"
    end

    local n = 0
    for k in pairs(d) do
        if type(k) ~= "number" then return nil, "the delays are not a list" end
        n = n + 1
    end
    if n == 0 then return nil, "a trial has to say what delay it ran at" end

    local out = {}
    for i = 1, n do
        local v = d[i]
        if v == nil then
            return nil, "the delay list has a hole in it, so its length is a guess"
        end
        if type(v) ~= "number" or v < 0 or math.floor(v) ~= v then
            return nil, ("delay %d is not a whole number of ticks"):format(i)
        end
        out[i] = v
    end
    return out
end

function M.delay_key(d)
    local list, why = M.delay_list(d)
    if not list then return nil, why end
    local parts = {}
    for i = 1, #list do parts[i] = ("%d"):format(list[i]) end
    return table.concat(parts, ",")
end

local function attempt_of(t)
    local a = t and t.attempt
    if type(a) ~= "number" or a < 1 or math.floor(a) ~= a then
        return nil, "a trial is the Nth attempt at its subject, and N starts at 1"
    end
    return a
end

-- Readable on purpose: this string lands in duplicate reports and in the
-- record's own id, where an operator has to recognise it.
function M.key(t)
    local subject, serr = M.subject(t)
    if not subject then return nil, serr end
    local dk, derr = M.delay_key(t.delays or t.delay)
    if not dk then return nil, derr end
    local attempt, aerr = attempt_of(t)
    if not attempt then return nil, aerr end
    return ("%s %s @ %s #%d"):format(subject.kind, subject.id, dk, attempt)
end

-- --- identity ----------------------------------------------------------------

function M.identity_of(rec)
    local p = (type(rec) == "table" and type(rec.provenance) == "table")
        and rec.provenance or {}
    return {
        character = rec and rec.character,
        control_scheme = rec and rec.control_scheme,
        game_patch = p.game_patch,
        calibration_id = p.calibration_id,
        conditions = rec and rec.conditions,
    }
end

-- Only the fields the caller actually scoped by are compared: a run that names
-- no calibration is asking about every line, and a run that names one is asking
-- about that one. A line missing a field the scope names does not match,
-- because unknown is not the same as equal - the rule GraphStore uses before it
-- will merge two graphs.
function M.identity_matches(want, have)
    if want == nil then return true, {} end
    local problems = {}
    for _, f in ipairs(M.IDENTITY_FIELDS) do
        local w = want[f]
        if w ~= nil then
            local h = have and have[f]
            if h == nil then
                problems[#problems + 1] = { field = f, problem = "not recorded on the line" }
            elseif h ~= w then
                problems[#problems + 1] = { field = f,
                    problem = ("%s, not %s"):format(tostring(h), tostring(w)) }
            end
        end
    end
    return #problems == 0, problems
end

-- --- building a record -------------------------------------------------------

local function problem(list, field, msg)
    list[#list + 1] = { field = field, problem = msg }
end

local function digest_of(program)
    if type(program) ~= "table" then return nil end
    return {
        total_ticks = program.total_ticks,
        tick_basis = program.tick_basis,
        profile_status = program.profile_status,
        profile_source = program.profile_source,
        observe_from_tick = program.observe_from_tick,
        -- Expected to be 0 or absent on anything a runner produced. Kept anyway,
        -- so a row built by some other path says which window it was watched in.
        tail_ticks = program.tail_ticks,
        swept_gap = program.swept_gap,
    }
end

-- spec:
--   edge_id | route_id | subject = { kind, id }
--   delays (one per gap) or delay (a single gap)
--   attempt    : 1-based
--   verdict    : a LinkVerdict.VERDICT
--   evidence   : the LinkVerdict result the verdict was read from
--   provenance : at least calibration_id and game_patch
--   program    : a SequenceCompiler program, for the digest
--
-- Returns record, or nil and the list of problems. Nothing is written for a
-- record that fails, and the problems come back rather than going to a log,
-- because a record that did not reach the file is exactly what somebody will
-- want to see.
function M.trial(spec)
    if type(spec) ~= "table" then
        return nil, { { field = "(root)", problem = "not a trial spec" } }
    end

    local problems = {}

    local subject, serr = M.subject(spec)
    if not subject then problem(problems, "subject", serr) end

    local delays, derr = M.delay_list(spec.delays or spec.delay)
    if not delays then problem(problems, "delays", derr) end

    local attempt, aerr = attempt_of(spec)
    if not attempt then problem(problems, "attempt", aerr) end

    local answers, verr = M.classify(spec.verdict)
    if not answers then problem(problems, "verdict", verr) end

    -- A trial injected through a button map nobody has measured is not evidence
    -- about anything: a wrong bit presses a button that does not exist, the move
    -- never comes out, and the row reads as a confident negative. A profile
    -- status that is absent is NOT this failure - unknown is not known-bad, and
    -- refusing on missing information is the mistake this project exists to
    -- avoid - so only a status that says otherwise is turned away.
    local pstatus = type(spec.program) == "table" and spec.program.profile_status or nil
    if SequenceCompiler.program_is_measured(spec.program) == false then
        problem(problems, "program.profile_status",
            ("the program was built with a %s profile, and a result injected "
             .. "through an unmeasured button map is not a result")
            :format(tostring(pstatus)))
    end

    if #problems > 0 then return nil, problems end

    -- Schema's TRIAL validator requires edge_id, so a route trial has to say
    -- something about it. It says `false`: known not to be about an edge, which
    -- is a different fact from nil, which would mean nobody recorded what this
    -- trial was about at all.
    local edge_id, route_id = false, nil
    if subject.kind == "edge" then edge_id = subject.id else route_id = subject.id end

    local rec = Schema.new(M.KIND, {
        id = spec.id or M.key(spec),
        edge_id = edge_id,
        route_id = route_id,
        subject_kind = subject.kind,
        subject_id = subject.id,
        delays = delays,
        delay = (#delays == 1) and delays[1] or nil,
        swept_gap = spec.swept_gap,
        attempt = attempt,
        verdict = spec.verdict,
        answers = answers,
        -- Spelled out so no consumer has to re-derive the mapping and get it
        -- wrong in the other direction.
        conclusive = (answers ~= M.ANSWERS.UNANSWERED),
        reason = spec.reason,
        evidence = spec.evidence,
        provenance = spec.provenance,
        character = spec.character,
        control_scheme = spec.control_scheme,
        conditions = spec.conditions,
        program = digest_of(spec.program),
        recorded_at = spec.recorded_at,
        -- Both clocks, when the caller had them. Every other tick number on this
        -- record is relative to the trial and resets on the next one, so these
        -- two are the only things that place a line anywhere: the wall clock in
        -- a recording, the frame in the engine's own time.
        started_at_frame = spec.started_at_frame,
        notes = spec.notes,
    })

    -- Through the schema's own machine rather than by assignment, so the
    -- evidence rule is enforced by the module that owns it.
    local ok, why = Schema.transition(rec, Schema.STATUS.RUNTIME_PENDING)
    if not ok then return nil, { { field = "status", problem = tostring(why) } } end
    local want = M.STATUS_FOR[answers]
    if want ~= Schema.STATUS.RUNTIME_PENDING then
        ok, why = Schema.transition(rec, want, spec.evidence)
        if not ok then return nil, { { field = "evidence", problem = tostring(why) } } end
    end

    local valid, vproblems = Schema.validate(M.KIND, rec)
    if not valid then return nil, vproblems end
    return rec
end

-- --- one line ----------------------------------------------------------------

-- Validation happens here as well as in M.trial, because this is the gate a
-- hand-built record also has to pass. Nothing reaches the file unvalidated.
function M.line(record, encode)
    if type(encode) ~= "function" then
        return nil, { { field = "encode", problem = "no encoder was injected" } }
    end
    local ok, problems = Schema.validate(M.KIND, record)
    if not ok then return nil, problems end

    local called, text = pcall(encode, record)
    if not called then
        return nil, { { field = "encode", problem = tostring(text) } }
    end
    if type(text) ~= "string" or text == "" then
        return nil, { { field = "encode", problem = "the encoder produced no text" } }
    end
    if text:find("[\r\n]") then
        -- An indenting encoder would write a record across twenty lines, every
        -- one of which reads back as corrupt. Better to refuse the first one.
        return nil, { { field = "encode",
            problem = "the encoded record spans more than one line, and this file "
                .. "is one complete record per line" } }
    end
    return text .. "\n"
end

function M.parse(text, decode)
    if type(text) ~= "string" then return nil, "not a line" end
    if type(decode) ~= "function" then return nil, "no decoder was injected" end
    local called, value, why = pcall(decode, text)
    if not called then return nil, tostring(value) end
    if type(value) ~= "table" then
        return nil, why and tostring(why) or "did not decode to a record"
    end
    return value
end

-- Splits raw file text into lines and says whether the last write finished. The
-- caller may also hand M.index a list of lines with opts.unterminated, for a
-- reader that has already done the splitting.
function M.scan(text)
    if type(text) ~= "string" then return nil, "not text" end
    local lines = {}
    local pos, n, intact = 1, #text, 0
    while pos <= n do
        local nl = text:find("\n", pos, true)
        if nl then
            lines[#lines + 1] = (text:sub(pos, nl - 1):gsub("\r$", ""))
            intact = nl
            pos = nl + 1
        else
            lines[#lines + 1] = text:sub(pos)
            pos = n + 1
        end
    end
    return lines, {
        unterminated = (n > 0 and text:sub(-1) ~= "\n"),
        -- Where the file has to be cut back to before anything is appended.
        intact_bytes = intact,
        lines = #lines,
    }
end

-- --- the index ---------------------------------------------------------------

local SNIPPET = 120

local function snippet(s)
    if type(s) ~= "string" then return nil end
    if #s <= SNIPPET then return s end
    return s:sub(1, SNIPPET) .. "..."
end

local function bump(tbl, key)
    if key == nil then return end
    tbl[key] = (tbl[key] or 0) + 1
end

-- source : the raw text of the file, or a list of lines
-- opts.decode         : required
-- opts.identity       : scope, see M.identity_matches
-- opts.unterminated   : when source is a list, whether its last line was cut off
-- opts.retry_verdicts : a set of verdicts that should NOT count as run, for an
--                       operator who has fixed the setup and wants the a_failed
--                       trials attempted again. Empty by default: a trial that
--                       reached a verdict has been run, whatever the verdict
--                       says.
--
-- One unreadable line never stops the read. Three thousand results are an hour
-- of somebody's evening and are not thrown away because line 812 is half a
-- record.
function M.index(source, opts)
    opts = opts or {}
    if type(opts.decode) ~= "function" then
        return nil, "no decoder was injected"
    end

    local lines, info
    if type(source) == "string" then
        lines, info = M.scan(source)
    elseif type(source) == "table" then
        lines = source
        info = { unterminated = (opts.unterminated == true) }
    else
        return nil, "nothing to index"
    end

    local ix = {
        identity = opts.identity,
        identity_checked = (opts.identity ~= nil),
        done = {},
        problems = {},
        by_verdict = {},
        by_subject = {},
        by_status = {},
        counts = {
            lines = #lines, trials = 0, unique = 0, duplicates = 0,
            blank = 0, truncated = 0, corrupt = 0, invalid = 0,
            unkeyable = 0, foreign = 0, retried = 0, unreadable = 0,
        },
    }

    local last = #lines
    local seen = {}

    for i = 1, last do
        local raw = lines[i]
        if i == last and info.unterminated then
            ix.counts.truncated = ix.counts.truncated + 1
            ix.problems[#ix.problems + 1] = {
                line = i, kind = "truncated", text = snippet(raw),
                reason = "the line has no terminator, so a trial ran and its result "
                    .. "was lost. It is not parsed even if it would decode, and it "
                    .. "does not count as having been run.",
            }
            ix.repair = {
                drop_line = i,
                intact_bytes = info.intact_bytes,
                reason = "cut the file back to intact_bytes before appending, or the "
                    .. "next record is glued onto the fragment and both are lost",
            }
        elseif type(raw) ~= "string" then
            ix.counts.corrupt = ix.counts.corrupt + 1
            ix.problems[#ix.problems + 1] = { line = i, kind = "corrupt",
                                              reason = "not a line of text" }
        elseif raw:match("^%s*$") then
            ix.counts.blank = ix.counts.blank + 1
        else
            local rec, why = M.parse(raw, opts.decode)
            if not rec then
                ix.counts.corrupt = ix.counts.corrupt + 1
                ix.problems[#ix.problems + 1] = { line = i, kind = "corrupt",
                                                  reason = tostring(why),
                                                  text = snippet(raw) }
            else
                local valid, vproblems = Schema.validate(M.KIND, rec)
                if not valid then
                    ix.counts.invalid = ix.counts.invalid + 1
                    ix.problems[#ix.problems + 1] = { line = i, kind = "invalid",
                                                      id = rec.id, problems = vproblems }
                else
                    local mine, mproblems =
                        M.identity_matches(opts.identity, M.identity_of(rec))
                    if not mine then
                        ix.counts.foreign = ix.counts.foreign + 1
                        ix.problems[#ix.problems + 1] = { line = i, kind = "foreign",
                                                          id = rec.id,
                                                          problems = mproblems }
                    else
                        ix.counts.trials = ix.counts.trials + 1
                        bump(ix.by_verdict, rec.verdict)
                        bump(ix.by_status, rec.status)
                        local subject = M.subject(rec)
                        if subject then bump(ix.by_subject, subject.id) end

                        local key, kerr = M.key(rec)
                        if not key then
                            -- Readable, and its verdict counts, but nothing can
                            -- ask whether it has been run - so it is reported
                            -- rather than left to cause a duplicate later.
                            ix.counts.unkeyable = ix.counts.unkeyable + 1
                            ix.problems[#ix.problems + 1] = { line = i, kind = "unkeyable",
                                                              id = rec.id,
                                                              reason = tostring(kerr) }
                        else
                            if seen[key] then
                                ix.counts.duplicates = ix.counts.duplicates + 1
                            end
                            seen[key] = true
                            if opts.retry_verdicts and opts.retry_verdicts[rec.verdict] then
                                ix.counts.retried = ix.counts.retried + 1
                                ix.done[key] = nil
                            else
                                ix.done[key] = { line = i, id = rec.id,
                                                 verdict = rec.verdict,
                                                 status = rec.status }
                            end
                        end
                    end
                end
            end
        end
    end

    local unique = 0
    for _ in pairs(ix.done) do unique = unique + 1 end
    ix.counts.unique = unique
    ix.counts.unreadable = ix.counts.truncated + ix.counts.corrupt + ix.counts.invalid
    return ix
end

-- --- the collector -----------------------------------------------------------

local function provenance_from(identity)
    if type(identity) ~= "table" then return nil end
    if identity.calibration_id == nil and identity.game_patch == nil then return nil end
    return {
        calibration_id = identity.calibration_id,
        game_patch = identity.game_patch,
        explorer_version = identity.explorer_version,
    }
end

-- opts.append / opts.encode : required
-- opts.decode               : required only when opts.resume is text or lines
-- opts.identity             : stamped onto every record and used to scope resume
-- opts.resume               : an index from M.index, or the raw text, or lines
-- opts.flush / opts.flush_every
function M.new(opts)
    opts = opts or {}
    if type(opts.append) ~= "function" then
        return nil, "no append function was injected, and a collector that cannot "
            .. "write is a sweep whose results do not exist"
    end
    if type(opts.encode) ~= "function" then
        return nil, "no encoder was injected"
    end

    local resume = opts.resume
    if resume ~= nil and not (type(resume) == "table" and resume.done ~= nil) then
        local ix, why = M.index(resume, { decode = opts.decode,
                                          identity = opts.identity,
                                          unterminated = opts.unterminated,
                                          retry_verdicts = opts.retry_verdicts })
        if not ix then return nil, why end
        resume = ix
    end

    return {
        append = opts.append,
        encode = opts.encode,
        flush = opts.flush,
        flush_every = opts.flush_every or 1,
        identity = opts.identity,
        resume = resume,
        done = {},
        problems = {},
        by_verdict = {},
        by_subject = {},
        by_status = {},
        counts = { written = 0, refused = 0, skipped = 0, write_failed = 0,
                   since_flush = 0 },
    }
end

-- Ask before running a trial. Returns true when it still has to be run, or
-- false and the reason it does not.
--
-- A trial that cannot be keyed is refused rather than run: it could never be
-- recognised on a resume, so it would be run again on every resume for ever.
function M.claim(c, spec)
    if type(c) ~= "table" then return false, "not a collector" end
    local key, why = M.key(spec)
    if not key then
        c.counts.refused = c.counts.refused + 1
        c.problems[#c.problems + 1] = { kind = "unkeyable", reason = why }
        return false, why
    end
    if c.done[key] then
        c.counts.skipped = c.counts.skipped + 1
        return false, "already run in this session"
    end
    local prior = c.resume and c.resume.done[key]
    if prior then
        c.counts.skipped = c.counts.skipped + 1
        return false, ("already run at line %d, verdict %s")
            :format(prior.line, tostring(prior.verdict))
    end
    return true
end

-- Builds, validates, formats and appends one trial. Returns the record, or nil
-- and its problems. The key is only marked done after the write reports having
-- succeeded, so a failed write leaves the trial to be run again rather than
-- recorded as done with nothing on disk.
function M.write(c, spec)
    if type(c) ~= "table" then
        return nil, { { field = "(root)", problem = "not a collector" } }
    end
    if type(spec) ~= "table" then
        c.counts.refused = c.counts.refused + 1
        return nil, { { field = "(root)", problem = "not a trial spec" } }
    end

    -- A copy: the caller's spec belongs to the caller, and the identity fields
    -- have to be on every line or a later resume cannot tell whose it is.
    local filled = {}
    for k, v in pairs(spec) do filled[k] = v end
    local id = c.identity
    if id then
        if filled.character == nil then filled.character = id.character end
        if filled.control_scheme == nil then filled.control_scheme = id.control_scheme end
        if filled.conditions == nil then filled.conditions = id.conditions end
        if filled.provenance == nil then filled.provenance = provenance_from(id) end
    end

    local rec, problems = M.trial(filled)
    if not rec then
        c.counts.refused = c.counts.refused + 1
        c.problems[#c.problems + 1] = { kind = "refused", id = filled.id,
                                        problems = problems }
        return nil, problems
    end

    local line, lproblems = M.line(rec, c.encode)
    if not line then
        c.counts.refused = c.counts.refused + 1
        c.problems[#c.problems + 1] = { kind = "refused", id = rec.id,
                                        problems = lproblems }
        return nil, lproblems
    end

    -- pcall, because a writer that throws must cost this one trial and not the
    -- rest of the hour.
    local called, ok, why = pcall(c.append, line)
    if not called then ok, why = false, tostring(ok) end
    if not ok then
        c.counts.write_failed = c.counts.write_failed + 1
        local p = { { field = "append",
                      problem = why and tostring(why)
                          or "the writer did not report success" } }
        c.problems[#c.problems + 1] = { kind = "write_failed", id = rec.id, problems = p }
        return nil, p
    end

    c.counts.written = c.counts.written + 1
    bump(c.by_verdict, rec.verdict)
    bump(c.by_status, rec.status)
    bump(c.by_subject, rec.subject_id)
    local key = M.key(rec)
    if key then c.done[key] = true end

    c.counts.since_flush = c.counts.since_flush + 1
    if c.flush and c.counts.since_flush >= c.flush_every then
        pcall(c.flush)
        c.counts.since_flush = 0
    end
    return rec
end

-- --- reporting ---------------------------------------------------------------

local function merged(a, b)
    local out = {}
    for k, v in pairs(a or {}) do out[k] = (out[k] or 0) + v end
    for k, v in pairs(b or {}) do out[k] = (out[k] or 0) + v end
    return out
end

-- What the file holds now: what was already on disk plus what this session
-- added, with the session's own tally kept separately so the operator can see
-- how much of the hour was resume and how much was work.
function M.summary(c)
    if type(c) ~= "table" then return nil, "not a collector" end
    local r = c.resume
    local rc = (r and r.counts) or {}
    return {
        identity = c.identity,
        trials = (rc.trials or 0) + c.counts.written,
        by_verdict = merged(r and r.by_verdict, c.by_verdict),
        by_subject = merged(r and r.by_subject, c.by_subject),
        by_status = merged(r and r.by_status, c.by_status),
        written = c.counts.written,
        refused = c.counts.refused,
        skipped = c.counts.skipped,
        write_failed = c.counts.write_failed,
        unreadable = rc.unreadable or 0,
        resumed = r and {
            lines = rc.lines, trials = rc.trials, unique = rc.unique,
            duplicates = rc.duplicates, blank = rc.blank, truncated = rc.truncated,
            corrupt = rc.corrupt, invalid = rc.invalid, unkeyable = rc.unkeyable,
            foreign = rc.foreign, retried = rc.retried, unreadable = rc.unreadable,
            repair = r.repair,
        } or nil,
    }
end

local function ordered(tbl)
    local keys = {}
    for k in pairs(tbl or {}) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        if tbl[a] ~= tbl[b] then return tbl[a] > tbl[b] end
        return tostring(a) < tostring(b)
    end)
    return keys
end

-- Lines for an operator staring at a menu, in a fixed order: pairs() over a
-- hash would reshuffle the report every time it was drawn.
function M.report(summary, opts)
    opts = opts or {}
    if type(summary) ~= "table" then return {} end
    local out = {}
    local function add(fmt, ...) out[#out + 1] = fmt:format(...) end

    add("trials on file: %d", summary.trials or 0)
    add("this session: %d written, %d skipped as already run, %d refused, "
        .. "%d writes failed",
        summary.written or 0, summary.skipped or 0, summary.refused or 0,
        summary.write_failed or 0)

    for _, v in ipairs(ordered(summary.by_verdict)) do
        add("  %-13s %d", v, summary.by_verdict[v])
    end

    local subjects = ordered(summary.by_subject)
    add("subjects: %d", #subjects)
    for i = 1, math.min(#subjects, opts.top_subjects or 5) do
        add("  %-40s %d", subjects[i], summary.by_subject[subjects[i]])
    end

    local r = summary.resumed
    if r then
        add("resumed from %d lines: %d usable, %d already answered",
            r.lines or 0, r.trials or 0, r.unique or 0)
        add("  unreadable %d (truncated %d, corrupt %d, invalid %d), "
            .. "foreign %d, blank %d, duplicates %d",
            r.unreadable or 0, r.truncated or 0, r.corrupt or 0, r.invalid or 0,
            r.foreign or 0, r.blank or 0, r.duplicates or 0)
        if r.repair then
            add("  the last line was cut off: one trial ran and its result was lost")
        end
    end
    return out
end

return M
