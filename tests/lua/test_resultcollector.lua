-- Unit tests for func/ComboExplorer/core/ResultCollector.lua
--
-- This module is the only thing standing between an hour of trials on the
-- gaming machine and an hour of trials that have to be run again, so what these
-- tests defend is mostly loss.
--
-- Resume has to be exact in both directions. A key too coarse skips a trial
-- nobody ran and leaves a hole no later stage can see; a key too fine re-runs
-- the hour that was already paid for. Both failures are silent, which is why
-- the volume tests here run over a realistic few thousand records rather than
-- three.
--
-- A crash leaves a half-written last line, and the two readings of it are
-- different facts: "this trial's result was lost" and "this trial never ran".
-- The first is what a truncated line means, because a line is only formatted
-- once its verdict exists. So it is reported, it is never parsed even when it
-- would decode, and it never counts as run.
--
-- And a verdict is not a status. `a_failed` and `wrong_move` are trials that
-- ran and answered nothing; writing them as `rejected` would turn missing
-- information into a negative result, which is the one thing this project
-- refuses to let happen anywhere.

local t = require("tests.lua.harness")
local RC = require("func/ComboExplorer/core/ResultCollector")
local Schema = require("func/ComboExplorer/core/Schema")
local LV = require("func/ComboExplorer/core/LinkVerdict")
local json = dofile("tools/lua/json.lua")

local ID = {
    character = "zangief",
    control_scheme = "modern",
    game_patch = "2026-05-01",
    calibration_id = "cal-7",
}

local PROV = { calibration_id = ID.calibration_id, game_patch = ID.game_patch }
local EVIDENCE = { combo_before_b = 1, combo_peak_b = 2, hits_added = 1,
                   b_latency_ticks = 4, observations = 44 }

local function spec_for(edge, delay, attempt, verdict)
    return {
        edge_id = edge, delay = delay, attempt = attempt,
        verdict = verdict or LV.VERDICT.LINK,
        evidence = EVIDENCE, provenance = PROV,
        character = ID.character, control_scheme = ID.control_scheme,
    }
end

local function line_for(edge, delay, attempt, verdict)
    local rec, problems = RC.trial(spec_for(edge, delay, attempt, verdict))
    if not rec then
        error("fixture would not build: " .. json.encode(problems))
    end
    return (RC.line(rec, json.encode))
end

local function has_problem(problems, field)
    for _, p in ipairs(problems or {}) do
        if p.field == field then return true end
    end
    return false
end

local function count_keys(tbl)
    local n = 0
    for _ in pairs(tbl or {}) do n = n + 1 end
    return n
end

local function sum_values(tbl)
    local n = 0
    for _, v in pairs(tbl or {}) do n = n + v end
    return n
end

-- --- one trial becomes one line ----------------------------------------------

t.group("one trial, one line")

local rec = RC.trial(spec_for("605:manual->621:manual", 4, 1, LV.VERDICT.LINK))
t.ok(rec ~= nil, "a complete trial spec produces a record")
t.eq(rec.schema, Schema.KIND.TRIAL, "tagged as a ce.trial.v1")
t.ok(Schema.validate(Schema.KIND.TRIAL, rec), "and the schema accepts it")
t.eq(rec.edge_id, "605:manual->621:manual", "the record names the edge it is about")
t.eq(rec.attempt, 1, "and which attempt it was")
t.eq(rec.delay, 4, "and the delay it ran at")
t.eq_list(rec.delays, { 4 }, "carried as a vector, because a route has more than one gap")

local line = RC.line(rec, json.encode)
t.eq(line:sub(-1), "\n", "the formatted line carries its own terminator")
t.eq(select(2, line:gsub("\n", "")), 1,
     "and exactly one, because the file is one complete record per line")

local back = json.decode(line)
t.ok(back ~= nil, "the line decodes back to a record")
t.eq(RC.key(back), RC.key(spec_for("605:manual->621:manual", 4, 1)),
     "and the key read back off disk is the key the sweep computed before it ran")
t.eq(back.id, rec.id, "the record's own id survives the round trip")

-- --- a verdict is not a status ------------------------------------------------

t.group("a verdict is not a status")

local function status_of(verdict)
    local r = RC.trial(spec_for("e1", 4, 1, verdict))
    return r and r.status, r and r.runtime_verified, r and r.answers
end

t.eq(status_of(LV.VERDICT.LINK), Schema.STATUS.VERIFIED,
     "a link is a result the game confirmed")
t.eq(status_of(LV.VERDICT.WHIFF), Schema.STATUS.REJECTED,
     "a whiff is a known negative about the link, and excludes it")
t.eq(status_of(LV.VERDICT.BLOCKED), Schema.STATUS.REJECTED,
     "so is a block: B connected and the victim was not in hitstun")
t.eq(status_of(LV.VERDICT.COMBO_BROKE), Schema.STATUS.REJECTED,
     "so is a broken combo counter")

t.eq(status_of(LV.VERDICT.A_FAILED), Schema.STATUS.RUNTIME_PENDING,
     "A never hitting answers nothing about the link, so it is not a rejection")
t.eq(status_of(LV.VERDICT.WRONG_MOVE), Schema.STATUS.RUNTIME_PENDING,
     "nor is the pad producing some other move: that is a fact about the input")
t.eq(status_of(LV.VERDICT.INCONCLUSIVE), Schema.STATUS.RUNTIME_PENDING,
     "nor is observing nothing at all")

t.eq(select(2, status_of(LV.VERDICT.A_FAILED)), false,
     "an unanswered trial claims nothing was verified")
t.eq(select(3, status_of(LV.VERDICT.A_FAILED)), RC.ANSWERS.UNANSWERED,
     "and says so in a field a consumer can read without re-deriving the mapping")
t.eq(select(2, status_of(LV.VERDICT.LINK)), true,
     "a link does carry runtime_verified, having been run on the game")

local unanswered_as_negative = 0
for _, verdict in pairs({ LV.VERDICT.A_FAILED, LV.VERDICT.WRONG_MOVE,
                          LV.VERDICT.INCONCLUSIVE }) do
    if status_of(verdict) == Schema.STATUS.REJECTED then
        unanswered_as_negative = unanswered_as_negative + 1
    end
end
t.eq(unanswered_as_negative, 0,
     "no verdict that answered nothing is ever written as a negative result")

local unknown, uproblems = RC.trial(spec_for("e1", 4, 1, "probably_worked"))
t.is_nil(unknown, "a verdict this module does not know is refused, not guessed at")
t.ok(has_problem(uproblems, "verdict"), "and the refusal names the verdict field")

t.is_nil(RC.trial({ edge_id = "e1", delay = 4, attempt = 1, evidence = EVIDENCE }),
         "a trial with no verdict at all is not a trial")

-- --- refusals -----------------------------------------------------------------

t.group("a record that fails does not get written")

local nosubject, nsproblems = RC.trial({ delay = 4, attempt = 1,
                                         verdict = LV.VERDICT.LINK,
                                         evidence = EVIDENCE, provenance = PROV })
t.is_nil(nosubject, "a trial that names neither an edge nor a route is refused")
t.ok(has_problem(nsproblems, "subject"), "and says which field is missing")

local both = RC.trial({ edge_id = "e1", route_id = "r1", delay = 4, attempt = 1,
                        verdict = LV.VERDICT.LINK, evidence = EVIDENCE,
                        provenance = PROV })
t.is_nil(both, "a trial that claims to be about both an edge and a route is refused")

local nodelay, ndproblems = RC.trial({ edge_id = "e1", attempt = 1,
                                       verdict = LV.VERDICT.LINK,
                                       evidence = EVIDENCE, provenance = PROV })
t.is_nil(nodelay, "a trial that does not say what delay it ran at is refused")
t.ok(has_problem(ndproblems, "delays"), "and the delay field is named")

t.is_nil(RC.trial(spec_for("e1", -1, 1)), "a negative delay is refused")
t.is_nil(RC.trial(spec_for("e1", 2.5, 1)), "so is a fractional tick")
t.ok(RC.trial(spec_for("e1", 0, 1)) ~= nil, "zero is a real delay and is accepted")

local holed = { edge_id = "e1", delays = { 3, nil, 5 }, attempt = 1,
                verdict = LV.VERDICT.LINK, evidence = EVIDENCE, provenance = PROV }
t.is_nil(RC.trial(holed), "a delay list with a hole in it is refused, not silently shortened")

t.is_nil(RC.trial({ edge_id = "e1", delay = 4, attempt = 0, verdict = LV.VERDICT.LINK,
                    evidence = EVIDENCE, provenance = PROV }),
         "attempt numbering starts at one, so a zeroth attempt is refused")
t.is_nil(RC.trial({ edge_id = "e1", delay = 4, verdict = LV.VERDICT.LINK,
                    evidence = EVIDENCE, provenance = PROV }),
         "and a trial with no attempt number cannot be told from its repeats")

local noev, evproblems = RC.trial({ edge_id = "e1", delay = 4, attempt = 1,
                                    verdict = LV.VERDICT.LINK, provenance = PROV })
t.is_nil(noev, "a verdict that claims the game answered has to carry the observations")
t.ok(has_problem(evproblems, "evidence"), "and the missing evidence is named")

local nocal = RC.trial({ edge_id = "e1", delay = 4, attempt = 1,
                         verdict = LV.VERDICT.LINK, evidence = EVIDENCE,
                         provenance = { game_patch = "2026-05-01" } })
t.is_nil(nocal, "a measured result has to name the calibration it was measured under")
local nopatch = RC.trial({ edge_id = "e1", delay = 4, attempt = 1,
                           verdict = LV.VERDICT.LINK, evidence = EVIDENCE,
                           provenance = { calibration_id = "cal-7" } })
t.is_nil(nopatch, "and the patch it was measured on")

local unverified_profile = spec_for("e1", 4, 1, LV.VERDICT.WHIFF)
unverified_profile.program = { total_ticks = 60, tick_basis = "explorer_tick",
                               profile_status = "unverified" }
local up, upproblems = RC.trial(unverified_profile)
t.is_nil(up, "a result injected through an unmeasured button map is not a result")
t.ok(has_problem(upproblems, "program.profile_status"),
     "and the refusal names the profile that was not measured")

local silent_profile = spec_for("e1", 4, 1, LV.VERDICT.WHIFF)
silent_profile.program = { total_ticks = 60, tick_basis = "explorer_tick" }
t.ok(RC.trial(silent_profile) ~= nil,
     "a program that says nothing about its profile is unknown, and unknown is not a refusal")

t.is_nil(RC.trial(nil), "no spec at all is refused")
t.is_nil(RC.trial("edge"), "and so is something that is not a spec")

-- --- formatting refusals ------------------------------------------------------

t.group("nothing unreadable is ever appended")

local function indenting(v) return json.encode(v, { indent = "  " }) end
local pretty, pproblems = RC.line(rec, indenting)
t.is_nil(pretty,
         "an encoder that pretty-prints would break one-record-per-line, and is refused")
t.ok(has_problem(pproblems, "encode"), "with the encoder named")

local threw = RC.line(rec, function() error("codec blew up") end)
t.is_nil(threw, "an encoder that throws is reported rather than taking the sweep with it")
t.is_nil(RC.line(rec, nil), "no encoder at all is refused")
t.is_nil(RC.line({ schema = "ce.edge.v1" }, json.encode),
         "and a record that is not a trial never reaches the encoder")

-- --- the resume key -----------------------------------------------------------

t.group("what the resume key has to be")

local three_a = { route_id = "r1", delays = { 3, 5 }, attempt = 1 }
local three_b = { route_id = "r1", delays = { 4, 5 }, attempt = 1 }
t.ok(RC.key(three_a) ~= RC.key(three_b),
     "two delay vectors that differ in any gap are different trials")
t.ok(RC.key(three_a) ~= RC.key({ route_id = "r1", delays = { 3, 5 }, attempt = 2 }),
     "and so are two attempts at the same delay, or repeats would collapse into one")
t.ok(RC.key({ edge_id = "x", delay = 1, attempt = 1 })
     ~= RC.key({ route_id = "x", delay = 1, attempt = 1 }),
     "an edge and a route that share an id are not the same subject")
t.eq(RC.key({ edge_id = "e", delay = 4, attempt = 1 }),
     RC.key({ edge_id = "e", delays = { 4 }, attempt = 1 }),
     "one delay and a one-gap vector are the same trial, however the caller spelled it")

t.is_nil(RC.key({ edge_id = "e", attempt = 1 }), "a trial with no delay cannot be keyed")
t.is_nil(RC.key({ delay = 4, attempt = 1 }), "nor one with no subject")
t.is_nil(RC.key({ edge_id = "e", delay = 4 }), "nor one with no attempt number")

local route_rec = RC.trial({ route_id = "r1", delays = { 3, 5 }, attempt = 2,
                             verdict = LV.VERDICT.LINK, evidence = EVIDENCE,
                             provenance = PROV })
t.ok(route_rec ~= nil, "a route trial builds")
t.eq(route_rec.edge_id, false,
     "and says it is known not to be about an edge, which nil would leave unsaid")
t.eq(RC.key(json.decode(RC.line(route_rec, json.encode))),
     RC.key({ route_id = "r1", delays = { 3, 5 }, attempt = 2 }),
     "a route trial keys the same after a round trip through the file")

-- --- a sweep's worth of results ------------------------------------------------

t.group("resume over a realistic file")

local SUBJECTS, DELAYS, ATTEMPTS = 100, 13, 3
local VERDICTS = { LV.VERDICT.LINK, LV.VERDICT.WHIFF, LV.VERDICT.BLOCKED,
                   LV.VERDICT.A_FAILED, LV.VERDICT.WRONG_MOVE, LV.VERDICT.COMBO_BROKE }

local function edge_name(i) return ("%d:manual->%d:manual"):format(600 + i, 700 + i) end

local parts = {}
for i = 1, SUBJECTS do
    for d = 0, DELAYS - 1 do
        for a = 1, ATTEMPTS do
            local verdict = VERDICTS[((i + d + a) % #VERDICTS) + 1]
            parts[#parts + 1] = line_for(edge_name(i), d, a, verdict)
        end
    end
end
local TOTAL = SUBJECTS * DELAYS * ATTEMPTS
local corpus = table.concat(parts)

t.eq(#parts, TOTAL, "the fixture is a sweep-sized file")

local ix = RC.index(corpus, { decode = json.decode, identity = ID })
t.eq(ix.counts.lines, TOTAL, "every line is accounted for")
t.eq(ix.counts.trials, TOTAL, "every line is a usable trial")
t.eq(ix.counts.unique, TOTAL, "and every one of them is a distinct trial")
t.eq(ix.counts.duplicates, 0, "with nothing recorded twice")
t.eq(ix.counts.unreadable, 0, "and nothing unreadable")
t.eq(sum_values(ix.by_verdict), TOTAL, "the verdict tally covers every trial")
t.eq(count_keys(ix.by_subject), SUBJECTS, "the subject tally names every subject")

local wrong_subject_totals = 0
for _, n in pairs(ix.by_subject) do
    if n ~= DELAYS * ATTEMPTS then wrong_subject_totals = wrong_subject_totals + 1 end
end
t.eq(wrong_subject_totals, 0, "each subject shows exactly its own trials")

local written = {}
local resumed = RC.new({ append = function(l) written[#written + 1] = l return true end,
                         encode = json.encode, identity = ID, resume = ix })
t.ok(resumed ~= nil, "a collector resumes from the index")

local rerun = 0
for i = 1, SUBJECTS do
    for d = 0, DELAYS - 1 do
        for a = 1, ATTEMPTS do
            if RC.claim(resumed, { edge_id = edge_name(i), delay = d, attempt = a }) then
                rerun = rerun + 1
            end
        end
    end
end
t.eq(rerun, 0, "a resumed sweep re-runs nothing it already has an answer for")
t.eq(resumed.counts.skipped, TOTAL, "and counts every trial it skipped")

local missed = 0
for i = 1, SUBJECTS do
    -- One delay past the end of the sweep and one attempt past its repeats:
    -- neither was ever run, and neither may be skipped.
    if not RC.claim(resumed, { edge_id = edge_name(i), delay = DELAYS, attempt = 1 }) then
        missed = missed + 1
    end
    if not RC.claim(resumed, { edge_id = edge_name(i), delay = 0,
                               attempt = ATTEMPTS + 1 }) then
        missed = missed + 1
    end
end
t.eq(missed, 0, "and skips nothing it has never run, at any delay or attempt")

t.ok(RC.claim(resumed, { route_id = edge_name(1), delay = 0, attempt = 1 }),
     "a route that happens to share an id with an edge is still unrun")

local unkeyable_ok = RC.claim(resumed, { edge_id = "e1", attempt = 1 })
t.eq(unkeyable_ok, false,
     "a trial that cannot be keyed is refused, since it could never be resumed")

-- --- the crash ----------------------------------------------------------------

t.group("a write that did not finish")

local fragment = parts[1]:sub(1, 60)
local crashed = corpus .. fragment
local cix = RC.index(crashed, { decode = json.decode, identity = ID })
t.eq(cix.counts.truncated, 1, "the half-written last line is reported")
t.eq(cix.counts.corrupt, 0, "not filed as corruption, which would be a different fact")
t.eq(cix.counts.trials, TOTAL, "and the results before it all survive the crash")
t.eq(cix.counts.unique, TOTAL, "every one of them still counts as run")
local repair = cix.repair or {}
t.eq(repair.drop_line, TOTAL + 1, "the repair names the line to drop")
t.eq(repair.intact_bytes, #corpus,
     "and where the file has to be cut back to before anything is appended")
local lost = cix.problems[1] or {}
t.eq(lost.kind, "truncated", "the problem list says what kind of loss it was")
t.eq(lost.line, TOTAL + 1, "and which line it was on")

-- The distinction the whole design turns on: a line whose terminator never
-- reached the disk is a lost result, not a result. Even when the bytes before
-- the cut happen to be a complete record.
local small = { line_for("a1", 0, 1, LV.VERDICT.LINK),
                line_for("a1", 1, 1, LV.VERDICT.WHIFF),
                line_for("a1", 2, 1, LV.VERDICT.LINK) }
local whole_but_unterminated = table.concat(small, "", 1, 2) .. small[3]:sub(1, -2)
local wix = RC.index(whole_but_unterminated, { decode = json.decode })
t.eq(wix.counts.truncated, 1, "a last line that would decode is still reported as truncated")
t.eq(wix.counts.trials, 2, "and is not counted among the results")
t.is_nil(wix.done[RC.key({ edge_id = "a1", delay = 2, attempt = 1 })],
         "a record without its terminator does not count as having been run")
t.ok(wix.done[RC.key({ edge_id = "a1", delay = 1, attempt = 1 })] ~= nil,
     "while the line before it, which finished, does")

local intact = RC.index(table.concat(small), { decode = json.decode })
t.eq(intact.counts.truncated, 0, "a file that ends in a terminator lost nothing")
t.is_nil(intact.repair, "and needs no repair")

local relost = RC.new({ append = function() return true end, encode = json.encode,
                        resume = wix })
t.ok(RC.claim(relost, { edge_id = "a1", delay = 2, attempt = 1 }),
     "the trial whose result was lost is run again, because a lost result is not an answer")

-- --- corruption ----------------------------------------------------------------

t.group("one bad line does not cost the others")

local ten = {}
for d = 0, 9 do ten[#ten + 1] = line_for("b1", d, 1, LV.VERDICT.LINK) end

local spliced = {}
for i = 1, 10 do spliced[#spliced + 1] = ten[i] end
spliced[4] = '{"schema":"ce.trial.v1","edge_id":"b1","del\n'
local gix = RC.index(table.concat(spliced), { decode = json.decode })
t.eq(gix.counts.corrupt, 1, "a line that will not parse is counted")
t.eq(gix.counts.trials, 9, "and the other nine results are read anyway")
local unparsed = gix.problems[1] or {}
t.eq(unparsed.line, 4, "the problem carries the line number, so it can be looked at")
t.eq(unparsed.kind, "corrupt", "and says the line would not parse")
t.ok(unparsed.text ~= nil, "and shows what was on it")

local missing = 0
for d = 0, 9 do
    if d ~= 3 and gix.done[RC.key({ edge_id = "b1", delay = d, attempt = 1 })] == nil then
        missing = missing + 1
    end
end
t.eq(missing, 0, "every readable trial in the file is still indexed as run")
t.is_nil(gix.done[RC.key({ edge_id = "b1", delay = 3, attempt = 1 })],
         "and the one that was corrupted is not, so it will be run again")

local notatable = {}
for i = 1, 10 do notatable[#notatable + 1] = ten[i] end
notatable[2] = "42\n"
local nix = RC.index(table.concat(notatable), { decode = json.decode })
t.eq(nix.counts.corrupt, 1, "a line that decodes to something that is not a record is corrupt")
t.eq(nix.counts.trials, 9, "and costs only itself")

local wrongkind = {}
for i = 1, 10 do wrongkind[#wrongkind + 1] = ten[i] end
wrongkind[7] = json.encode({ schema = "ce.edge.v1", id = "e", status = "theoretical" }) .. "\n"
local kix = RC.index(table.concat(wrongkind), { decode = json.decode })
t.eq(kix.counts.invalid, 1, "a line that parses but is not a trial is reported as invalid")
t.eq(kix.counts.corrupt, 0, "not as corruption: it parsed perfectly well")
t.eq(kix.counts.trials, 9, "and the trials around it are unaffected")
local notatrial = kix.problems[1] or {}
t.eq(notatrial.line, 7, "with the line named")
t.ok(#(notatrial.problems or {}) > 0, "and the schema's own complaints attached")

local blanks = {}
for i = 1, 10 do blanks[#blanks + 1] = ten[i] end
table.insert(blanks, 5, "\n")
local bix = RC.index(table.concat(blanks), { decode = json.decode })
t.eq(bix.counts.blank, 1, "a blank line is counted as blank")
t.eq(bix.counts.corrupt, 0, "and not as corruption, since it never claimed to be a record")
t.eq(bix.counts.trials, 10, "and every result is still read")

-- A record the schema is happy with but that nothing can ask about: its result
-- is readable, its identity as a trial is not. Counted, reported, and left out
-- of the index rather than quietly turning into a duplicate later.
local keyless = json.encode({ schema = Schema.KIND.TRIAL, id = "t1", edge_id = "b1",
                              status = Schema.STATUS.RUNTIME_PENDING,
                              runtime_verified = false, attempt = 1,
                              verdict = LV.VERDICT.A_FAILED }) .. "\n"
local kless = RC.index(table.concat(ten) .. keyless, { decode = json.decode })
t.eq(kless.counts.unkeyable, 1, "a trial that does not say what delay it ran at is reported")
t.eq(kless.counts.trials, 11, "its verdict still counts, because the line was readable")
t.eq(kless.counts.unique, 10, "but it cannot answer whether that trial has been run")

local mixed = {}
for i = 1, 10 do mixed[#mixed + 1] = ten[i] end
mixed[2] = "{oops\n"
mixed[7] = json.encode({ schema = "ce.edge.v1", id = "e", status = "theoretical" }) .. "\n"
local mix = RC.index(table.concat(mixed) .. "{\"half", { decode = json.decode })
t.eq(mix.counts.unreadable, 3,
     "the unreadable tally is every line whose result cannot be recovered")
t.eq(mix.counts.trials, 8, "and the rest of the file is still results")

-- --- identity ------------------------------------------------------------------

t.group("results measured under something else are not answers here")

local other = RC.trial({ edge_id = "c1", delay = 4, attempt = 1, verdict = LV.VERDICT.LINK,
                         evidence = EVIDENCE, character = ID.character,
                         control_scheme = ID.control_scheme,
                         provenance = { calibration_id = "cal-6",
                                        game_patch = ID.game_patch } })
local oix = RC.index(RC.line(other, json.encode), { decode = json.decode, identity = ID })
t.eq(oix.counts.foreign, 1, "a line from another calibration is set aside")
t.eq(oix.counts.trials, 0, "and does not count as a trial of this run")
t.is_nil(oix.done[RC.key({ edge_id = "c1", delay = 4, attempt = 1 })],
         "so the sweep runs it again rather than trusting a different calibration")
t.ok(#((oix.problems[1] or {}).problems or {}) > 0, "and the mismatching field is named")

local unstamped = RC.trial({ edge_id = "c1", delay = 4, attempt = 1,
                             verdict = LV.VERDICT.LINK, evidence = EVIDENCE,
                             provenance = PROV })
local uix = RC.index(RC.line(unstamped, json.encode),
                     { decode = json.decode, identity = ID })
t.eq(uix.counts.foreign, 1,
     "a line that does not say which character it was measured on is not a match")
t.eq(uix.counts.trials, 0, "because unknown is not the same as equal")

local anyix = RC.index(RC.line(other, json.encode), { decode = json.decode })
t.eq(anyix.counts.foreign, 0, "a run that scopes by nothing is asking about every line")
t.eq(anyix.counts.trials, 1, "and reads them all")
t.eq(anyix.identity_checked, false, "and says that no identity was checked")

-- --- retrying what answered nothing ---------------------------------------------

t.group("verdicts the operator wants tried again")

local retryable = { line_for("d1", 0, 1, LV.VERDICT.LINK),
                    line_for("d1", 1, 1, LV.VERDICT.A_FAILED),
                    line_for("d1", 2, 1, LV.VERDICT.WHIFF) }
local rix = RC.index(table.concat(retryable), { decode = json.decode })
t.eq(rix.counts.unique, 3, "by default every trial that reached a verdict counts as run")

local rix2 = RC.index(table.concat(retryable), { decode = json.decode,
                                                 retry_verdicts = { a_failed = true } })
t.eq(rix2.counts.trials, 3, "an operator can ask for a verdict to be tried again")
t.eq(rix2.counts.retried, 1, "with the number of trials that reopens reported")
t.eq(rix2.counts.unique, 2, "so that trial no longer counts as answered")
t.is_nil(rix2.done[RC.key({ edge_id = "d1", delay = 1, attempt = 1 })],
         "and the sweep will run it again")
t.ok(rix2.done[RC.key({ edge_id = "d1", delay = 2, attempt = 1 })] ~= nil,
     "while the whiff, which did answer, stays answered")

local dupes = RC.index(table.concat({ retryable[1], retryable[1] }),
                       { decode = json.decode })
t.eq(dupes.counts.duplicates, 1, "a trial recorded twice is reported as a duplicate")
t.eq(dupes.counts.unique, 1, "and counted once as answered")

-- --- writing --------------------------------------------------------------------

t.group("writing")

local out, flushes = {}, 0
local c = RC.new({
    append = function(l) out[#out + 1] = l return true end,
    encode = json.encode,
    flush = function() flushes = flushes + 1 end,
    identity = ID,
})
t.ok(c ~= nil, "a collector with somewhere to write is built")

local w = RC.write(c, { edge_id = "w1", delay = 4, attempt = 1,
                        verdict = LV.VERDICT.LINK, evidence = EVIDENCE })
t.ok(w ~= nil, "a trial is written")
t.eq(#out, 1, "one line reached the writer")
t.eq(flushes, 1, "and was flushed, because a buffered result is a result a crash takes")
t.eq(w.provenance.calibration_id, ID.calibration_id,
     "the collector stamps the calibration onto every record")
t.eq(w.character, ID.character, "and the character, so a later resume can tell whose it is")

local written_back = json.decode(out[1])
t.eq(written_back.verdict, LV.VERDICT.LINK, "what was written is what comes back")
t.eq(RC.claim(c, { edge_id = "w1", delay = 4, attempt = 1 }), false,
     "and the collector will not run the same trial twice in one session")

local bad, bproblems = RC.write(c, { edge_id = "w1", delay = 4, attempt = 2 })
t.is_nil(bad, "a trial with no verdict is refused")
t.eq(#out, 1, "and nothing was appended for it")
t.ok(#bproblems > 0, "the problems come back to the caller")
t.eq(c.counts.refused, 1, "and the refusal is counted")

local failing = RC.new({ append = function() return false, "disk full" end,
                         encode = json.encode, identity = ID })
local f, fproblems = RC.write(failing, { edge_id = "w2", delay = 1, attempt = 1,
                                         verdict = LV.VERDICT.WHIFF, evidence = EVIDENCE })
t.is_nil(f, "a write that failed is reported as a failure")
t.eq(failing.counts.write_failed, 1, "and counted")
t.ok(has_problem(fproblems, "append"), "with the writer's own reason attached")
t.ok(RC.claim(failing, { edge_id = "w2", delay = 1, attempt = 1 }),
     "the trial is not marked done, because nothing reached the disk")

local silent = RC.new({ append = function() end, encode = json.encode, identity = ID })
t.is_nil(RC.write(silent, { edge_id = "w3", delay = 1, attempt = 1,
                            verdict = LV.VERDICT.WHIFF, evidence = EVIDENCE }),
         "a writer that reports nothing counts as having failed")
t.eq(silent.counts.write_failed, 1,
     "because believing a write that did not happen loses the result for good")

local throwing = RC.new({ append = function() error("the file handle went away") end,
                          encode = json.encode, identity = ID })
local th = RC.write(throwing, { edge_id = "w4", delay = 1, attempt = 1,
                                verdict = LV.VERDICT.WHIFF, evidence = EVIDENCE })
t.is_nil(th, "a writer that throws costs one trial")
t.eq(throwing.counts.write_failed, 1, "and not the rest of the hour")

local batched, batch_flushes = {}, 0
local slow = RC.new({ append = function(l) batched[#batched + 1] = l return true end,
                      flush = function() batch_flushes = batch_flushes + 1 end,
                      encode = json.encode, flush_every = 5, identity = ID })
for i = 1, 12 do
    RC.write(slow, { edge_id = "w5", delay = i, attempt = 1,
                     verdict = LV.VERDICT.WHIFF, evidence = EVIDENCE })
end
t.eq(#batched, 12, "a caller may buffer if it insists")
t.eq(batch_flushes, 2, "and the flush interval is honoured exactly")

-- --- the operator's summary -------------------------------------------------------

t.group("what the operator is told")

local more = {}
local session = RC.new({ append = function(l) more[#more + 1] = l return true end,
                         encode = json.encode, identity = ID, decode = json.decode,
                         resume = corpus })
t.ok(session ~= nil, "a collector can be handed the raw file and index it itself")
t.eq(session.resume.counts.trials, TOTAL, "reading the whole sweep back")

local added = 0
for i = 1, SUBJECTS do
    if RC.claim(session, { edge_id = edge_name(i), delay = DELAYS, attempt = 1 }) then
        if RC.write(session, { edge_id = edge_name(i), delay = DELAYS, attempt = 1,
                               verdict = LV.VERDICT.LINK, evidence = EVIDENCE }) then
            added = added + 1
        end
    end
end
t.eq(added, SUBJECTS, "the session extends the sweep by one delay per subject")

local sum = RC.summary(session)
t.eq(sum.trials, TOTAL + SUBJECTS, "the summary counts everything the file now holds")
t.eq(sum.written, SUBJECTS, "how much of that this session wrote")
t.eq(sum.skipped, 0, "how much it skipped as already answered")
t.eq(sum.resumed.trials, TOTAL, "and how much it inherited")
t.eq(sum.unreadable, 0, "with the unreadable lines called out")
t.eq(sum_values(sum.by_verdict), TOTAL + SUBJECTS, "the verdict tally covers every trial")
t.eq(count_keys(sum.by_subject), SUBJECTS, "and the subject tally every subject")
t.eq(sum.by_subject[edge_name(1)], DELAYS * ATTEMPTS + 1,
     "each subject's count includes both the resumed trials and the new one")

local report = RC.report(sum)
t.ok(#report > 0, "the summary renders for a human")
t.eq_list(RC.report(sum), report,
     "and renders the same way twice, rather than reshuffling on every draw")

local crashed_session = RC.new({ append = function() return true end, encode = json.encode,
                                 decode = json.decode, identity = ID, resume = crashed })
local csum = RC.summary(crashed_session)
t.eq(csum.unreadable, 1, "a resumed run says how many results could not be read back")
t.ok(csum.resumed.repair ~= nil, "and hands on the repair the file needs")

-- --- degenerate input ---------------------------------------------------------------

t.group("degenerate input")

t.is_nil(RC.new({ encode = json.encode }),
         "a collector with no way to write is refused rather than silently discarding")
t.is_nil(RC.new({ append = function() return true end }), "and one with no encoder")
t.is_nil(RC.index(corpus, {}), "indexing without a decoder is refused")
t.is_nil(RC.index(nil, { decode = json.decode }), "and so is indexing nothing")

local empty = RC.index("", { decode = json.decode })
t.eq(empty.counts.lines, 0, "an empty file has no lines")
t.eq(empty.counts.trials, 0, "no trials")
t.eq(empty.counts.truncated, 0, "and nothing was lost in it")
t.is_nil(empty.repair, "so it needs no repair")

local onlynewline = RC.index("\n", { decode = json.decode })
t.eq(onlynewline.counts.blank, 1, "a file of one empty line is one blank line")
t.eq(onlynewline.counts.truncated, 0, "and is terminated, so nothing was cut off")

local one_line = (line_for("z1", 0, 1, LV.VERDICT.LINK):gsub("\n$", ""))
local lines_in = RC.index({ one_line }, { decode = json.decode })
t.eq(lines_in.counts.trials, 1, "a caller that has already split the file may pass lines")
local cut = RC.index({ one_line }, { decode = json.decode, unterminated = true })
t.eq(cut.counts.truncated, 1, "and say that the last of them was cut off")

t.is_nil(RC.parse("{}", nil), "parsing without a decoder is refused")
t.is_nil(RC.parse(nil, json.decode), "and parsing something that is not a line")
t.is_nil(RC.summary(nil), "a summary of nothing is refused")
t.eq_list(RC.report(nil), {}, "and a report of nothing is empty rather than an error")

return t.finish()
