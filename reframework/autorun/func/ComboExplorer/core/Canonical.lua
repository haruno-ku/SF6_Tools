-- =========================================================
-- ComboExplorer/core/Canonical.lua - which action id a notation group actually
-- produces on THIS build, applied to a worklist.
-- =========================================================
--
-- THE PROBLEM, MEASURED
--
-- A worklist is a list of action ids. The catalog it was generated from lists
-- several ids under one notation, because the notation is what the move DISPLAYS
-- and Modern has one button where classic had two:
--
--   601  motion 弱  classic LP
--   602  motion 弱  classic LP
--   611  motion 弱  classic LK
--
-- Pressing Modern's 弱 produces exactly one of those. Which one is not in the
-- data - command_display has no field for it and _meta says nothing - so
-- Provenance.action_id_canonical asks the question and the calibration sweep
-- answers it by pressing the button and watching. On build 24176760 it came
-- back verified: manual|弱 is 611.
--
-- Nothing read it. Measured on hardware, 2026-09-12: the first sweep wrote 15
-- rows and every one said "move A never came out", because every one was
-- waiting for 601. The observation was correct; the expectation was
-- unreachable. Of 378 pairs, 209 had an A in a group the calibration had
-- measured and only 61 of those named the id the button actually produces -
-- so 148 pairs could not have succeeded, and a night would have been spent
-- confirming that unreachable ids do not come out.
--
-- WHY HERE AND NOT IN THE WORKLIST GENERATOR
--
-- The worklist is generated off-machine, from frame data the gaming PC does not
-- have. The canonical map is a MEASUREMENT OF ONE BUILD. Baking a build's
-- measurement into a static artifact is the thing Provenance exists to stop:
-- after that, a worklist carried to another build is wrong and nothing says so.
-- So the worklist stays build-independent and the register is applied to it
-- here, once, at the start of a run.
--
-- WHY THE DUPLICATES HAVE TO COLLAPSE
--
-- Rewriting ids alone is not enough. 601, 602 and 611 all resolve to 611, so
-- three pairs become the same trial under three different edge_ids - the same
-- button pressed three times and recorded as three separate findings, two of
-- which are fabrications. The fold is the point, not a tidy-up: it is what
-- turns "the matrix inflates threefold" (Provenance's own if_wrong for this
-- entry) back into one row per real move.
--
-- WHAT IT REFUSES TO DO
--
-- A group the sweep never pressed is left exactly as it was. Guessing that the
-- lowest id in a group is the real one would be a measurement-shaped assumption
-- with no measurement under it, and it would be invisible afterwards: the rows
-- would look like every other row. Untouched pairs stay untouched and the
-- report says how many there are, so an operator reading a result knows which
-- part of it rested on a measurement and which part did not.

local M = { name = "ComboExplorer.Canonical" }

-- The key a canonical map is written under: "<input_method>|<notation>", the
-- same string the calibration's action sweep builds when it records what came
-- out. Written once here so the two sides cannot drift.
function M.group_key(method, notation)
    if method == nil or notation == nil then return nil end
    local m, n = tostring(method), tostring(notation)
    if m == "" or n == "" then return nil end
    return m .. "|" .. n
end

-- The id this group actually produces, or nil for "nobody measured this one".
--
-- nil is not an error and is not a default. It is the answer for every group
-- outside the sweep's reach, and the caller's job is to leave those alone.
function M.resolve(canonical, method, notation)
    if type(canonical) ~= "table" then return nil end
    local key = M.group_key(method, notation)
    if not key then return nil end
    local id = tonumber(canonical[key])
    return id
end

local function pair_key(p)
    return ("%s:%s->%s:%s"):format(tostring(p.a_id), tostring(p.a_method),
                                   tostring(p.b_id), tostring(p.b_method))
end

-- worklist  : a decoded ce.worklist.v1
-- canonical : the action_id_canonical value, or nil
--
-- Returns a NEW worklist and a report. The input is never modified: the same
-- decoded document is what the checksum comparison ran against, and a run that
-- is restarted has to see the same thing twice.
--
-- The report is the part an operator reads:
--   remapped   how many pairs had an id rewritten to what the button produces
--   folded     how many pairs were dropped because another pair became them
--   untouched  how many pairs name a group nobody has measured
--   kept       how many pairs the sweep will actually run
function M.apply(worklist, canonical)
    if type(worklist) ~= "table" or type(worklist.pairs) ~= "table" then
        return nil, "not a worklist"
    end

    local report = { remapped = 0, folded = 0, untouched = 0, kept = 0,
                     groups_used = {}, groups_unmeasured = {} }

    -- No map at all is not a failure: an operator may be sweeping before the
    -- calibration has run. Every pair is untouched and the report says so,
    -- which is a very different sentence from "0 remapped" on a map that
    -- existed and matched nothing.
    local have_map = type(canonical) == "table" and next(canonical) ~= nil

    local out, seen = {}, {}
    for _, p in ipairs(worklist.pairs) do
        local q = {}
        for k, v in pairs(p) do q[k] = v end

        local touched = false
        local unmeasured = false

        local a = M.resolve(canonical, p.a_method, p.a_notation)
        if a then
            if a ~= q.a_id then touched = true end
            q.a_id = a
            report.groups_used[M.group_key(p.a_method, p.a_notation)] = true
        elseif have_map then
            unmeasured = true
            local k = M.group_key(p.a_method, p.a_notation)
            if k then report.groups_unmeasured[k] = true end
        end

        local b = M.resolve(canonical, p.b_method, p.b_notation)
        if b then
            if b ~= q.b_id then touched = true end
            q.b_id = b
            report.groups_used[M.group_key(p.b_method, p.b_notation)] = true
        elseif have_map then
            unmeasured = true
            local k = M.group_key(p.b_method, p.b_notation)
            if k then report.groups_unmeasured[k] = true end
        end

        -- Recorded on the pair rather than only counted, because a row written
        -- from it has to be able to say what it rested on. A trial whose ids
        -- came from a measurement and one whose ids came from the catalog's
        -- arbitrary pick within a group are not the same claim.
        q.canonical_applied = touched or nil
        q.canonical_unmeasured = unmeasured or nil

        if touched then report.remapped = report.remapped + 1 end
        if unmeasured then report.untouched = report.untouched + 1 end

        -- The fold. Two pairs that resolve to the same two ids by the same two
        -- methods ARE the same trial, whatever the catalog called them, and
        -- running both would record one button press as two findings.
        local key = pair_key(q)
        if seen[key] then
            report.folded = report.folded + 1
        else
            seen[key] = true
            out[#out + 1] = q
        end
    end

    report.kept = #out

    local wl = {}
    for k, v in pairs(worklist) do wl[k] = v end
    wl.pairs = out
    wl.count = #out
    -- Stamped on the worklist so a reader of it, and the artifact written from
    -- it, can tell a canonicalised list from the shipped one.
    wl.canonical = have_map and {
        remapped = report.remapped,
        folded = report.folded,
        untouched = report.untouched,
    } or nil

    return wl, report
end

-- One line for the panel and for a log. Says what happened to the list rather
-- than only how long it now is: "378 -> 230" without the reason reads like the
-- worklist was truncated.
function M.summary(report)
    if type(report) ~= "table" then return "no canonical report" end
    return ("%d pair(s): %d remapped to the id the button produces, %d folded "
        .. "as duplicates of another pair, %d naming a group nobody measured")
        :format(report.kept, report.remapped, report.folded, report.untouched)
end

return M
