-- =========================================================
-- tools/lua/sweepreport.lua - what the sweep logs say, folded into one model a
-- page can draw. Dev-machine only, like the rest of tools/.
-- =========================================================
--
-- WHY THIS EXISTS
--
-- Every trial the game has run so far sits in a JSONL file, one attempt per
-- line. confirm.lua turns one log into a list of pairs, and that list is the
-- right input for the next stage of the chain - but nobody can LOOK at 216
-- lines, or at a list, and see that the whole "> 中" column never produced its
-- move. The shape of a failure is a picture before it is a number.
--
-- So this builds the model and report.lua writes it into an HTML page. The
-- model is kept pure - tables in, tables out, no file access - so the numbers
-- the page shows have a test, like every other number this project makes
-- decisions from.
--
-- WHAT IT IS CAREFUL ABOUT
--
-- The same two things confirm.lua is careful about.
--
-- An unanswered trial is drawn as unanswered, not as a failure. wrong_move and
-- a_failed are the pad not producing the move; they say nothing about the link.
-- The classification goes through ResultCollector.classify, so a verdict added
-- upstream and not taught to that module shows up as unknown rather than being
-- quietly given a colour.
--
-- And a pair the compiler could never have pressed (#49) is MARKED, not hidden.
-- Its trials still ran and still say what they say. The mark is what tells a
-- reader not to believe them.
--
-- THE COMBO LIST
--
-- The first thing anybody wants from all of this is "which combos are known to
-- connect", and until now the answer was spread across seven logs. M.build
-- gathers every trial that linked into one list, keyed by the MOVES rather than
-- by how they were pressed: 2+弱 into SA2 is one combo whether the SA came out
-- of 236236+中 or 4+SP+强, and both inputs are listed under it.
--
-- A combo is listed as confirmed once it has linked in two trials. Not at one
-- delay, which is ConfirmedEdge's rule for a pair: that rule answers "is the
-- window at this gap reproducible", and the question here is "does this combo
-- connect at all". A route that linked at nineteen different gaps has answered
-- that nineteen times. One link is listed too, as seen once, because it is a
-- real observation and hiding it would lose it - but it is not called confirmed.
--
-- WHAT IS NOT HERE
--
-- The link decision. ConfirmedEdge owns "is this pair verified" - cohorts,
-- stability, minimum attempts - and a page that re-derived it would drift from
-- the document that actually feeds the chain. A cell here shows what the
-- trials in ONE log said, which is a fact about that log and nothing more.

local InputMask       = require("func/ComboExplorer/core/InputMask")
local ResultCollector = require("func/ComboExplorer/core/ResultCollector")

local M = { name = "tools.sweepreport" }

-- --- what one step can press (#49) ------------------------------------------

-- InputMask.compile plays a motion one direction per tick, so 236236, 63214 and
-- the 360 shorthand all come out - the logs show 930, 1010 and 1206 appearing.
-- What it cannot play is the same direction twice in a row: 22 becomes DOWN
-- for two ticks, which is one held DOWN, not two presses. That, and a "> X"
-- follow-up that only exists after a specific previous move, compile without
-- complaint and then produce nothing - which is why they are named here rather
-- than left to the trials.
--
-- #49 counted every multi-direction motion as unpressable (121 pairs). The
-- trials disagree for everything except a repeated direction.
M.PRESS = {
    OK = "single",           -- what the compiler can play
    REPEAT = "repeat",       -- the same direction twice in a row: 22
    FOLLOWUP = "followup",   -- "> X": only exists after a specific previous move
    UNREADABLE = "unreadable",
}

function M.press_kind(notation)
    local parsed = InputMask.parse(notation)
    if not parsed then return M.PRESS.UNREADABLE end
    if parsed.followup then return M.PRESS.FOLLOWUP end
    local dirs = InputMask.MOTION_SHORTHAND[parsed.dirs] or parsed.dirs
    if dirs:find("(%d)%1") then return M.PRESS.REPEAT end
    return M.PRESS.OK
end

-- A pair takes the worst of its two steps. Follow-up outranks a repeat because
-- it cannot be fixed by pressing better: in a two-step route the move before it
-- is the wrong context by construction.
local PRESS_RANK = { single = 0, ["repeat"] = 1, followup = 2, unreadable = 3 }

local function worse(a, b)
    return PRESS_RANK[a] >= PRESS_RANK[b] and a or b
end

-- --- keys --------------------------------------------------------------------

local function side_key(id, method)
    return ("%s:%s"):format(tostring(id), tostring(method))
end

function M.pair_key(p)
    return side_key(p.a_id, p.a_method) .. "->" .. side_key(p.b_id, p.b_method)
end

-- "zangief-assist-ground-truth@40/2" -> "zangief-assist-ground-truth", {40, 2}
function M.route_subject(edge_id)
    if type(edge_id) ~= "string" then return nil end
    local id, tail = edge_id:match("^(.-)@([%d/]+)$")
    if not id or id == "" then return nil end
    local gaps = {}
    for n in tail:gmatch("%d+") do gaps[#gaps + 1] = tonumber(n) end
    return id, gaps
end

-- --- one trial ----------------------------------------------------------------

local ANSWER_RANK = { positive = 3, negative = 2, unanswered = 1, unknown = 0 }

local function answer_of(rec)
    local m = ResultCollector.classify(rec.verdict)
    return m or "unknown"
end

-- The cell's headline: a link anywhere in the cell is the thing to see, then a
-- real negative, then the pad having done something else. Within a class the
-- verdict seen most often wins, ties broken by name so the page is stable.
local function headline(verdicts)
    local best, best_rank, best_n = nil, -1, -1
    local names = {}
    for v in pairs(verdicts) do names[#names + 1] = v end
    table.sort(names)
    for _, v in ipairs(names) do
        local n = verdicts[v]
        local rank = ANSWER_RANK[ResultCollector.classify(v) or "unknown"]
        if rank > best_rank or (rank == best_rank and n > best_n) then
            best, best_rank, best_n = v, rank, n
        end
    end
    return best
end

local function add_trial(cell, rec)
    cell.rows = cell.rows + 1
    local v = tostring(rec.verdict)
    cell.verdicts[v] = (cell.verdicts[v] or 0) + 1
    local d = rec.delay
    if type(d) == "number" then
        cell.delays[#cell.delays + 1] = { delay = d, verdict = v }
    end
    -- The last reason written is the one shown. Every reason is still in the log.
    cell.reason = rec.reason or cell.reason
    if rec.evidence and type(rec.evidence.actions_seen) == "table" then
        local seen = {}
        for _, a in ipairs(rec.evidence.actions_seen) do seen[#seen + 1] = a.action_id end
        cell.actions_seen = seen
    end
end

local function new_cell()
    return { rows = 0, verdicts = {}, delays = {} }
end

local function finish_cell(cell)
    cell.verdict = headline(cell.verdicts)
    cell.answer = cell.verdict and answer_of({ verdict = cell.verdict }) or nil
    table.sort(cell.delays, function(a, b) return a.delay < b.delay end)
    return cell
end

-- --- the worklist ------------------------------------------------------------

-- Axes in worklist order, grouped by what the step can press so the columns a
-- reader should not trust sit together instead of scattered through the grid.
local GROUP_ORDER = { "single", "repeat", "followup", "unreadable" }

local function axes(pairs_list)
    local starters, targets = {}, {}
    local seen_a, seen_b = {}, {}
    for _, p in ipairs(pairs_list) do
        local ak, bk = side_key(p.a_id, p.a_method), side_key(p.b_id, p.b_method)
        if not seen_a[ak] then
            seen_a[ak] = true
            starters[#starters + 1] = { key = ak, id = p.a_id, method = p.a_method,
                                        notation = p.a_notation, press = M.press_kind(p.a_notation) }
        end
        if not seen_b[bk] then
            seen_b[bk] = true
            targets[#targets + 1] = { key = bk, id = p.b_id, method = p.b_method,
                                      notation = p.b_notation, press = M.press_kind(p.b_notation) }
        end
    end

    local rank = {}
    for i, g in ipairs(GROUP_ORDER) do rank[g] = i end
    for i, t in ipairs(targets) do t.order = i end
    table.sort(targets, function(x, y)
        if x.press ~= y.press then return rank[x.press] < rank[y.press] end
        return x.order < y.order
    end)
    for _, t in ipairs(targets) do t.order = nil end
    return starters, targets
end

-- --- the model ----------------------------------------------------------------

-- --- the combo list -------------------------------------------------------------

M.COMBO = { CONFIRMED = "confirmed", ONCE = "once" }
M.CONFIRM_LINKS = 2

-- steps : { { id, notation }, ... } in order. The key is the moves alone.
local function combo_key(steps)
    local ids = {}
    for i, s in ipairs(steps) do ids[i] = tostring(s.id) end
    return table.concat(ids, ">")
end

local function note_combo_trial(book, steps, rec, log_name, gap_label)
    local key = combo_key(steps)
    local c = book[key]
    if not c then
        c = { key = key, steps = {}, inputs = {}, input_seen = {},
              attempts = 0, links = 0, negatives = 0, unanswered = 0,
              linked_gaps = {}, gap_seen = {}, logs = {}, log_seen = {} }
        for i, s in ipairs(steps) do c.steps[i] = { id = s.id } end
        book[key] = c
    end

    local m = answer_of(rec)
    c.attempts = c.attempts + 1
    if m == "positive" then
        c.links = c.links + 1
        -- Inputs and logs are recorded from the trials that LINKED. A spelling
        -- that only ever whiffed is not a way to perform this combo.
        local names = {}
        for i, s in ipairs(steps) do names[i] = tostring(s.notation) end
        local spelled = table.concat(names, "\n")
        if not c.input_seen[spelled] then
            c.input_seen[spelled] = true
            c.inputs[#c.inputs + 1] = names
        end
        if gap_label and not c.gap_seen[gap_label] then
            c.gap_seen[gap_label] = true
            c.linked_gaps[#c.linked_gaps + 1] = gap_label
        end
        if not c.log_seen[log_name] then
            c.log_seen[log_name] = true
            c.logs[#c.logs + 1] = log_name
        end
        local at = rec.recorded_at
        if type(at) == "string" then
            if not c.first_linked_at or at < c.first_linked_at then c.first_linked_at = at end
            if not c.last_linked_at or at > c.last_linked_at then c.last_linked_at = at end
        end
    elseif m == "negative" then
        c.negatives = c.negatives + 1
    else
        c.unanswered = c.unanswered + 1
    end
end

-- Gap labels sort by their numbers, not as strings: "4" before "22".
local function gap_less(x, y)
    local xs, ys = {}, {}
    for n in x:gmatch("%d+") do xs[#xs + 1] = tonumber(n) end
    for n in y:gmatch("%d+") do ys[#ys + 1] = tonumber(n) end
    for i = 1, math.max(#xs, #ys) do
        if (xs[i] or -1) ~= (ys[i] or -1) then return (xs[i] or -1) < (ys[i] or -1) end
    end
    return false
end

local function finish_combos(book, classic)
    local list = {}
    for _, c in pairs(book) do
        if c.links > 0 then
            c.input_seen, c.gap_seen, c.log_seen = nil, nil, nil
            c.status = c.links >= M.CONFIRM_LINKS and M.COMBO.CONFIRMED or M.COMBO.ONCE
            for _, s in ipairs(c.steps) do s.classic = classic and classic[s.id] or nil end
            table.sort(c.linked_gaps, gap_less)
            -- Nothing measures damage yet. Said as a field rather than left out,
            -- because ce.verified_combo.v1 requires it and a list that did not
            -- mention it would read as ready to publish.
            c.damage_measured = false
            list[#list + 1] = c
        end
    end
    table.sort(list, function(x, y)
        if x.status ~= y.status then return x.status == M.COMBO.CONFIRMED end
        if #x.steps ~= #y.steps then return #x.steps > #y.steps end
        if x.links ~= y.links then return x.links > y.links end
        return x.key < y.key
    end)
    return list
end

-- --- the model ----------------------------------------------------------------

-- inputs:
--   worklist : decoded ce.worklist.v1
--   logs     : { { name, path, records = {...}, bad_lines = n }, ... }
--   routes   : { [route_id] = decoded ce.route.v1 }
--   classic  : optional { [action_id] = classic notation }, for the combo list
-- Returns the model. Never fails on a log it cannot place: rows that match
-- neither a worklist pair nor a route are counted as `elsewhere`, by key, so a
-- reader can see that they exist.
function M.build(worklist, logs, routes, classic)
    routes = routes or {}
    local book = {}
    local wl_pairs = (worklist and worklist.pairs) or {}
    local starters, targets = axes(wl_pairs)

    local target_by_key, starter_by_key = {}, {}
    for _, t in ipairs(targets) do target_by_key[t.key] = t end
    for _, s in ipairs(starters) do starter_by_key[s.key] = s end

    local model = {
        character = worklist and worklist.character,
        control_scheme = worklist and worklist.control_scheme,
        worklist = {
            generated_at = worklist and worklist.generated_at,
            game_patch = worklist and worklist.game_patch,
            count = #wl_pairs,
        },
        starters = starters,
        targets = targets,
        pairs = {},
        press = { single = 0, ["repeat"] = 0, followup = 0, unreadable = 0 },
        pair_logs = {},
        route_logs = {},
    }

    for _, p in ipairs(wl_pairs) do
        local key = M.pair_key(p)
        local kind = worse(starter_by_key[side_key(p.a_id, p.a_method)].press,
                           target_by_key[side_key(p.b_id, p.b_method)].press)
        model.press[kind] = model.press[kind] + 1
        model.pairs[key] = {
            a = side_key(p.a_id, p.a_method), b = side_key(p.b_id, p.b_method),
            confidence = p.confidence, margin_frames = p.margin_frames, press = kind,
            steps = { { id = p.a_id, notation = p.a_notation },
                      { id = p.b_id, notation = p.b_notation } },
        }
    end

    for _, log in ipairs(logs or {}) do
        local pair_cells, route_cells = {}, {}
        local counts = { verdicts = {}, answers = {}, rows = 0, elsewhere = 0 }
        local elsewhere = {}
        local first_at, last_at = nil, nil
        local calibrations, seen_cal = {}, {}

        for _, rec in ipairs(log.records or {}) do
            counts.rows = counts.rows + 1
            local v = tostring(rec.verdict)
            counts.verdicts[v] = (counts.verdicts[v] or 0) + 1
            local a = answer_of(rec)
            counts.answers[a] = (counts.answers[a] or 0) + 1

            local at = rec.recorded_at
            if type(at) == "string" then
                if not first_at or at < first_at then first_at = at end
                if not last_at or at > last_at then last_at = at end
            end
            local cal = rec.provenance and rec.provenance.calibration_id
            if cal and not seen_cal[cal] then
                seen_cal[cal] = true
                calibrations[#calibrations + 1] = cal
            end

            local key = rec.edge_id or rec.subject_id
            local route_id, gaps = M.route_subject(key)
            if model.pairs[key] then
                pair_cells[key] = pair_cells[key] or new_cell()
                add_trial(pair_cells[key], rec)
                note_combo_trial(book, model.pairs[key].steps, rec, log.name,
                    type(rec.delay) == "number" and tostring(rec.delay) or nil)
            elseif route_id then
                if type(rec.delays) == "table" and #rec.delays > 0 then gaps = rec.delays end
                local r = route_cells[route_id] or { cells = {}, gaps = {} }
                route_cells[route_id] = r
                local gk = table.concat(gaps, "/")
                r.cells[gk] = r.cells[gk] or new_cell()
                add_trial(r.cells[gk], rec)
                -- Without its definition a route's moves are unknown, so it is
                -- listed under its own id rather than guessed into steps.
                local def = routes[route_id]
                local steps = { { id = route_id, notation = route_id } }
                if def and type(def.steps) == "table" then
                    steps = {}
                    for i, s in ipairs(def.steps) do
                        steps[i] = { id = s.action_id, notation = s.notation }
                    end
                end
                note_combo_trial(book, steps, rec, log.name, gk)
                for i, g in ipairs(gaps) do
                    r.gaps[i] = r.gaps[i] or {}
                    r.gaps[i][g] = true
                end
            else
                counts.elsewhere = counts.elsewhere + 1
                elsewhere[#elsewhere + 1] = tostring(key)
            end
        end

        for _, c in pairs(pair_cells) do finish_cell(c) end

        local base = {
            name = log.name, path = log.path, counts = counts,
            first_at = first_at, last_at = last_at, calibrations = calibrations,
            unreadable_lines = log.bad_lines or 0,
        }

        if next(pair_cells) or (counts.elsewhere > 0 and not next(route_cells)) then
            base.cells = pair_cells
            base.elsewhere = elsewhere
            model.pair_logs[#model.pair_logs + 1] = base
        end

        for route_id, r in pairs(route_cells) do
            for _, c in pairs(r.cells) do finish_cell(c) end
            local axes_out = {}
            for i, set in ipairs(r.gaps) do
                local list = {}
                for g in pairs(set) do list[#list + 1] = g end
                table.sort(list)
                axes_out[i] = list
            end
            local def = routes[route_id]
            model.route_logs[#model.route_logs + 1] = {
                name = log.name, path = log.path, route_id = route_id,
                counts = counts, first_at = first_at, last_at = last_at,
                calibrations = calibrations, unreadable_lines = log.bad_lines or 0,
                steps = def and def.steps or nil, note = def and def.note or nil,
                gap_axes = axes_out, cells = r.cells,
            }
        end
    end

    -- Oldest first: the logs are a sequence of experiments, and each one exists
    -- because of what the previous one showed.
    local function by_time(x, y)
        return (x.first_at or "") < (y.first_at or "")
    end
    table.sort(model.pair_logs, by_time)
    table.sort(model.route_logs, by_time)

    model.combos = finish_combos(book, classic)
    return model
end

return M
